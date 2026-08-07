# 01_irf_response_speed.R

rm(list = ls())

pkgs <- c("fixest", "data.table", "dplyr", "ggplot2")
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
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/4] 读取数据并生成 z-score 冲击的滞后项...\n")
panel_full <- fread(file = file.path(MID_DIR, "panel_for_robustness.csv"), encoding = "UTF-8")
panel_full[, YearMonth := as.Date(YearMonth)]

# 为 z-score 冲击生成 L1-L6
for (shock_var in c("PolZ_Agg", "PolZ_CHN_Partner", "PolZ_Partner_CHN")) {
  if (!(shock_var %in% names(panel_full))) next
  for (h in 1:6) {
    panel_full[, (paste0(shock_var, "_L", h)) := shift(get(shock_var), n = h, type = "lag"), by = .(db, ISO)]
  }
}

DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
# 使用 z-score 水平序列作为冲击（而非 AR(1) 残差），以保留政治分数的持续性信息，
# 否则 AR(1) 残差接近白噪声，动态响应会全部集中在 L0。
SHOCK_MAP <- list(
  "Pol_Agg" = "PolZ_Agg",
  "Pol_CHN_Partner" = "PolZ_CHN_Partner",
  "Pol_Partner_CHN" = "PolZ_Partner_CHN"
)
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
HORIZONS <- 0:6
MIN_OBS <- 100

# ----------------------------------------------------------------------------
# 2) 运行局部投影 IRF
# ----------------------------------------------------------------------------
cat("[2/4] 局部投影 IRF 估计（h = 0..6）...\n")

run_ppml_irf <- function(dt, trade, shock_var, h) {
  x_var <- if (h == 0) shock_var else paste0(shock_var, "_L", h)
  if (!(x_var %in% names(dt))) return(NULL)
  
  dt_fit <- dt[!is.na(get(trade)) & !is.na(get(x_var)) &
                 !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  if (nrow(dt_fit) < MIN_OBS) return(NULL)
  if (uniqueN(dt_fit$ISO) < 3) return(NULL)
  
  formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth", trade, x_var, paste(CONTROLS, collapse = " + "))
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)
  
  ct <- coeftable(fit)
  if (!(x_var %in% rownames(ct))) return(NULL)
  
  data.table(
    h = h,
    estimate = as.numeric(ct[x_var, "Estimate"]),
    se = as.numeric(ct[x_var, "Std. Error"]),
    pvalue = as.numeric(ct[x_var, "Pr(>|z|)"]),
    n = nrow(dt_fit)
  )
}

results <- list()
for (db_label in DBS) {
  dt_db <- panel_full[db == db_label]
  if (nrow(dt_db) == 0) next
  
  for (pol_name in names(SHOCK_MAP)) {
    shock_var <- SHOCK_MAP[[pol_name]]
    if (!(shock_var %in% names(dt_db))) next
    # Tsinghua 只有 u_Agg
    if (db_label == "Tsinghua" && pol_name != "Pol_Agg") next
    
    for (trade in TRADE_VARS) {
      for (h in HORIZONS) {
        res <- run_ppml_irf(dt_db, trade, shock_var, h)
        if (is.null(res)) next
        res[, db := db_label]
        res[, pol_var := pol_name]
        res[, trade := trade]
        results[[length(results) + 1]] <- res
      }
    }
  }
}

irf_dt <- rbindlist(results, use.names = TRUE, fill = TRUE)
fwrite(irf_dt, file.path(OUT_DIR, "irf_coefficients.csv"))
cat(sprintf("✓ irf_coefficients.csv 已保存 (%d 行)\n", nrow(irf_dt)))

# ----------------------------------------------------------------------------
# 3) 计算 IRF 响应速度指标
# ----------------------------------------------------------------------------
cat("[3/4] 计算 IRF 响应速度指标...\n")

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
      n = first(dt$n)
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
    n = first(dt$n)
  )
}

irf_metrics <- irf_dt[, compute_metrics(.SD), by = .(db, trade, pol_var)]
irf_metrics[, method := "IRF"]
fwrite(irf_metrics, file.path(OUT_DIR, "irf_response_speed.csv"))
cat(sprintf("✓ irf_response_speed.csv 已保存 (%d 行)\n", nrow(irf_metrics)))
print(irf_metrics[order(db, trade, pol_var)])

# ----------------------------------------------------------------------------
# 4) 与分布滞后（DL）全样本结果对比
# ----------------------------------------------------------------------------
cat("[4/4] 与分布滞后（DL）全样本结果对比...\n")

# 读取 03 全样本基准系数并计算其响应速度指标
dl_baseline <- fread(file = file.path(TEST_DIR, "..", "检验结果CSV", "full_sample_baseline.csv"), encoding = "UTF-8")
dl_metrics <- dl_baseline[, compute_metrics(.SD), by = .(db, trade, pol_var)]
dl_metrics[, method := "DL_FullSample"]

comparison <- rbindlist(list(irf_metrics, dl_metrics), use.names = TRUE, fill = TRUE)
comp_wide <- dcast(comparison, db + trade + pol_var ~ method, value.var = "avg_response_lag")
fwrite(comp_wide, file.path(OUT_DIR, "irf_vs_dl_comparison.csv"))
cat(sprintf("✓ irf_vs_dl_comparison.csv 已保存 (%d 行)\n", nrow(comp_wide)))
print(comp_wide)

# 散点图：IRF vs DL 平均响应滞后
comp_plot <- comp_wide[!is.na(IRF) & !is.na(DL_FullSample)]
if (nrow(comp_plot) > 0) {
  p <- ggplot(comp_plot, aes(x = DL_FullSample, y = IRF, color = db)) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "grey50") +
    geom_point(size = 3, alpha = 0.7) +
    geom_text(aes(label = paste0(pol_var, "\n", trade)), size = 2.5, vjust = -0.5, check_overlap = TRUE) +
    labs(
      title = "IRF vs 分布滞后：全样本平均响应滞后对比",
      subtitle = "IRF 使用 AR(1) 残差冲击；虚线为 45° 参考线",
      x = "分布滞后（DL）平均响应滞后（月）",
      y = "局部投影 IRF 平均响应滞后（月）",
      color = "数据库"
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom")
  
  ggsave(file.path(FIG_DIR, "fig01_irf_vs_dl_comparison.png"), p, width = 10, height = 8, dpi = 300)
  cat("✓ fig01_irf_vs_dl_comparison.png\n")
}

cat("IRF 响应速度分析完成。\n")
