# 02_standardization_robustness.R

rm(list = ls())

pkgs <- c("fixest", "data.table", "dplyr", "ggplot2", "tidyr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
FIG_DIR <- file.path(TEST_DIR, "图片")
MID_DIR <- file.path(TEST_DIR, "中间数据")

cat("[1/5] 读取数据...\n")
panel_full <- fread(file = file.path(MID_DIR, "panel_for_robustness.csv"), encoding = "UTF-8")
panel_full[, YearMonth := as.Date(YearMonth)]

windows <- fread(file = file.path(TEST_DIR, "..", "中间数据", "windows.csv"), encoding = "UTF-8")
windows[, window_start := as.Date(window_start)]
windows[, window_end := as.Date(window_end)]
windows[, window_midpoint := as.Date(window_midpoint)]

# 为 z-score 冲击生成 L1-L6
for (shock_var in c("PolZ_Agg", "PolZ_CHN_Partner", "PolZ_Partner_CHN")) {
  if (!(shock_var %in% names(panel_full))) next
  panel_full[, (paste0(shock_var, "_L0")) := get(shock_var)]
  for (h in 1:6) {
    panel_full[, (paste0(shock_var, "_L", h)) := shift(get(shock_var), n = h, type = "lag"), by = .(db, ISO)]
  }
}
# AR(1) 冲击的 L0-L6 已由 00_utils 生成
# （实际上 00_utils 仅生成 u_Agg/u_CHN_Partner/u_Partner_CHN，需在此补齐 L0-L6）
for (shock_var in c("u_Agg", "u_CHN_Partner", "u_Partner_CHN")) {
  if (!(shock_var %in% names(panel_full))) next
  panel_full[, (paste0(shock_var, "_L0")) := get(shock_var)]
  for (h in 1:6) {
    panel_full[, (paste0(shock_var, "_L", h)) := shift(get(shock_var), n = h, type = "lag"), by = .(db, ISO)]
  }
}

DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
HORIZONS <- 0:6
MIN_OBS <- 100

METHODS <- list(
  "Raw" = list(prefix = "Pol"),
  "ZScore" = list(prefix = "PolZ"),
  "AR1" = list(prefix = "u")
)

run_one_dl <- function(dt_fit, trade, pol, method_prefix) {
  lag_vars <- paste0(method_prefix, "_", pol, "_L", HORIZONS)
  if (!all(lag_vars %in% names(dt_fit))) return(NULL)
  
  all_vars <- c(trade, lag_vars, CONTROLS)
  dt_use <- dt_fit
  for (v in all_vars) dt_use <- dt_use[!is.na(get(v))]
  if (nrow(dt_use) < MIN_OBS) return(NULL)
  if (uniqueN(dt_use$ISO) < 3) return(NULL)
  
  rhs <- paste(lag_vars, collapse = " + ")
  formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth", trade, rhs, paste(CONTROLS, collapse = " + "))
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_use, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)
  
  ct <- coeftable(fit)
  out <- list()
  for (h in HORIZONS) {
    vname <- paste0(method_prefix, "_", pol, "_L", h)
    if (vname %in% rownames(ct)) {
      out[[length(out) + 1]] <- data.table(
        h = h,
        estimate = as.numeric(ct[vname, "Estimate"]),
        se = as.numeric(ct[vname, "Std. Error"]),
        pvalue = as.numeric(ct[vname, "Pr(>|z|)"])
      )
    } else {
      out[[length(out) + 1]] <- data.table(h = h, estimate = NA_real_, se = NA_real_, pvalue = NA_real_)
    }
  }
  res <- rbindlist(out, use.names = TRUE)
  res[, n := nrow(dt_use)]
  res[, n_country := uniqueN(dt_use$ISO)]
  return(res)
}

compute_metrics <- function(dt) {
  dt <- dt[order(h)]
  est <- dt$estimate
  pv <- dt$pvalue
  h_vec <- dt$h
  valid <- !is.na(est)
  if (sum(valid) == 0) {
    return(data.table(
      avg_response_lag = NA_real_,
      immediate_share = NA_real_,
      peak_lag = NA_integer_,
      sig_lags_count = NA_integer_,
      sum_abs_coef = NA_real_,
      n = first(dt$n),
      n_country = first(dt$n_country)
    ))
  }
  abs_est <- abs(est)
  sum_abs <- sum(abs_est, na.rm = TRUE)
  avg_lag <- if (sum_abs > 0) sum(abs_est * h_vec, na.rm = TRUE) / sum_abs else NA_real_
  imm_share <- if (sum_abs > 0) abs_est[h_vec == 0] / sum_abs else NA_real_
  if (length(imm_share) == 0) imm_share <- NA_real_
  peak_lag <- if (sum_abs > 0) h_vec[which.max(abs_est)] else NA_integer_
  sig_count <- sum(!is.na(pv) & pv < 0.05, na.rm = TRUE)
  data.table(
    avg_response_lag = avg_lag,
    immediate_share = imm_share,
    peak_lag = peak_lag,
    sig_lags_count = as.integer(sig_count),
    sum_abs_coef = sum_abs,
    n = first(dt$n),
    n_country = first(dt$n_country)
  )
}

# ----------------------------------------------------------------------------
# 2) 滚动窗口估计（Z-Score 与 AR(1) Residual）
# ----------------------------------------------------------------------------
cat("[2/5] 滚动窗口估计（Z-Score / AR(1) Residual）...\n")

results <- list()
n_total <- nrow(windows) * length(DBS) * length(TRADE_VARS) * 3 * 2  # 3 pol * 2 methods
pb <- txtProgressBar(min = 0, max = n_total, style = 3)
prog <- 0

for (wi in seq_len(nrow(windows))) {
  w <- windows[wi]
  dt_w <- panel_full[YearMonth >= w$window_start & YearMonth <= w$window_end]
  
  for (db_label in DBS) {
    dt_db <- dt_w[db == db_label]
    if (nrow(dt_db) == 0) {
      prog <- prog + length(TRADE_VARS) * 3 * 2
      setTxtProgressBar(pb, prog)
      next
    }
    
    for (trade in TRADE_VARS) {
      for (pol in c("Agg", "CHN_Partner", "Partner_CHN")) {
        for (meth in c("ZScore", "AR1")) {
          prog <- prog + 1
          setTxtProgressBar(pb, prog)
          
          if (db_label == "Tsinghua" && pol != "Agg") next
          
          prefix <- METHODS[[meth]]$prefix
          res <- run_one_dl(dt_db, trade, pol, prefix)
          if (is.null(res)) next
          
          res[, window_id := w$window_id]
          res[, db := db_label]
          res[, trade := trade]
          res[, pol_var := paste0("Pol_", pol)]
          res[, method := meth]
          results[[length(results) + 1]] <- res
        }
      }
    }
  }
}
close(pb)

coef_z_ar <- rbindlist(results, use.names = TRUE, fill = TRUE)

# ----------------------------------------------------------------------------
# 3) 计算响应速度指标
# ----------------------------------------------------------------------------
cat("[3/5] 计算 Z-Score / AR(1) 响应速度指标...\n")
metrics_z_ar <- coef_z_ar[, compute_metrics(.SD), by = .(window_id, db, trade, pol_var, method)]
metrics_z_ar <- merge(metrics_z_ar, windows[, .(window_id, window_midpoint)], by = "window_id", all.x = TRUE)

# 读取 Raw 方法的结果（来自 03_响应速度复现）
raw_metrics <- fread(file = file.path(TEST_DIR, "..", "检验结果CSV", "response_speed_metrics.csv"), encoding = "UTF-8")
raw_metrics <- raw_metrics[, .(window_id, db, trade, pol_var,
                               avg_response_lag, immediate_share, peak_lag, sig_lags_count)]
raw_metrics[, method := "Raw"]

all_metrics <- rbindlist(list(raw_metrics, metrics_z_ar), use.names = TRUE, fill = TRUE)
fwrite(all_metrics, file.path(OUT_DIR, "robustness_standardization_metrics.csv"))
cat(sprintf("✓ robustness_standardization_metrics.csv 已保存 (%d 行)\n", nrow(all_metrics)))

# ----------------------------------------------------------------------------
# 4) 跨方法相关性
# ----------------------------------------------------------------------------
cat("[4/5] 计算跨方法相关性...\n")

corr_dt <- all_metrics[!is.na(avg_response_lag), .(window_id, db, trade, pol_var, method, avg_response_lag)]
corr_wide <- dcast(corr_dt, window_id + db + trade + pol_var ~ method, value.var = "avg_response_lag")

corr_summary <- corr_wide[, {
  r_raw_z <- cor(.SD[["Raw"]], .SD[["ZScore"]], use = "pairwise.complete.obs")
  r_raw_ar1 <- cor(.SD[["Raw"]], .SD[["AR1"]], use = "pairwise.complete.obs")
  r_z_ar1 <- cor(.SD[["ZScore"]], .SD[["AR1"]], use = "pairwise.complete.obs")
  n_obs <- sum(complete.cases(.SD[, .(Raw, ZScore, AR1)]))
  .(r_raw_z = r_raw_z, r_raw_ar1 = r_raw_ar1, r_z_ar1 = r_z_ar1, n_obs = n_obs)
}, by = .(db, trade, pol_var)]

fwrite(corr_summary, file.path(OUT_DIR, "robustness_standardization_correlation.csv"))
cat(sprintf("✓ robustness_standardization_correlation.csv 已保存 (%d 行)\n", nrow(corr_summary)))
print(corr_summary)

# ----------------------------------------------------------------------------
# 5) 可视化
# ----------------------------------------------------------------------------
cat("[5/5] 绘制标准化稳健性图...\n")

plot_dt <- all_metrics[!is.na(avg_response_lag)]
plot_dt[, method_label := factor(method, levels = c("Raw", "ZScore", "AR1"),
                                  labels = c("原值", "z-score", "AR(1) 残差"))]
plot_dt[, trade_label := factor(trade,
                                 levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                                 labels = c("总贸易", "出口", "进口"))]

p <- ggplot(plot_dt, aes(x = window_midpoint, y = avg_response_lag,
                           color = method_label, group = method_label)) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 1.2) +
  facet_grid(trade_label + pol_var ~ db, scales = "free_y") +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "标准化方式稳健性：滚动窗口平均响应滞后",
    subtitle = "比较原值、z-score、AR(1) 残差三种处理方式",
    x = "窗口中点年份",
    y = "平均响应滞后（月）",
    color = "处理方式"
  ) +
  theme_minimal(base_size = 9) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 7),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 6)
  )

ggsave(file.path(FIG_DIR, "fig02_standardization_stability.png"), p, width = 18, height = 16, dpi = 300)
cat("✓ fig02_standardization_stability.png\n")

cat("标准化稳健性分析完成。\n")
