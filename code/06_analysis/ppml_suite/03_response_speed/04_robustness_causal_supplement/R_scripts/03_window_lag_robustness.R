# 03_window_lag_robustness.R

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
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/5] 读取数据并生成滞后项（最长 12 阶）...\n")
panel_full <- fread(file = file.path(MID_DIR, "panel_for_robustness.csv"), encoding = "UTF-8")
panel_full[, YearMonth := as.Date(YearMonth)]

# 仅对 PolZ_Agg 生成 L0-L12（标准化后综合指数）
panel_full[, PolZ_Agg_L0 := PolZ_Agg]
for (h in 1:12) {
  panel_full[, (paste0("PolZ_Agg_L", h)) := shift(PolZ_Agg, n = h, type = "lag"), by = .(db, ISO)]
}

DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
WINDOW_LENGTHS <- c(36, 60, 84)
LAG_ORDERS <- c(3, 6, 12)
MIN_OBS <- 100

# ----------------------------------------------------------------------------
# 2) 构造滚动窗口
# ----------------------------------------------------------------------------
cat("[2/5] 构造 36/60/84 个月滚动窗口...\n")

make_windows <- function(L) {
  # 起止年份：保证窗口完全落在 2002-2025 样本内
  last_start_year <- 2025 - L / 12 + 1
  starts <- seq.Date(as.Date("2002-01-01"),
                     as.Date(paste0(last_start_year, "-01-01")),
                     by = "12 months")
  ends <- vapply(starts, function(s) {
    seq.Date(from = s, by = paste(L, "months"), length.out = 2)[2] - 1
  }, FUN.VALUE = as.Date("2000-01-01"))
  mids <- vapply(starts, function(s) {
    seq.Date(from = s, by = paste(L / 2, "months"), length.out = 2)[2]
  }, FUN.VALUE = as.Date("2000-01-01"))
  data.table(
    window_id = seq_along(starts),
    window_start = as.Date(starts),
    window_end = as.Date(ends),
    window_midpoint = as.Date(mids),
    window_length = L
  )
}

windows_all <- rbindlist(lapply(WINDOW_LENGTHS, make_windows), use.names = TRUE)
fwrite(windows_all, file.path(MID_DIR, "robustness_windows_36_60_84.csv"))
cat(sprintf("✓ 共生成 %d 个窗口\n", nrow(windows_all)))

# ----------------------------------------------------------------------------
# 3) 滚动窗口分布滞后估计
# ----------------------------------------------------------------------------
cat("[3/5] 滚动窗口分布滞后估计...\n")

run_one_dl <- function(dt_fit, trade, max_lag) {
  lag_vars <- paste0("PolZ_Agg_L", 0:max_lag)
  if (!all(lag_vars %in% names(dt_fit))) return(NULL)
  
  all_vars <- c(trade, lag_vars, CONTROLS)
  dt_use <- dt_fit
  for (v in all_vars) dt_use <- dt_use[!is.na(get(v))]
  if (nrow(dt_use) < MIN_OBS) return(NULL)
  if (uniqueN(dt_use$ISO) < 3) return(NULL)
  
  rhs <- paste(lag_vars, collapse = " + ")
  formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                         trade, rhs, paste(CONTROLS, collapse = " + "))
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_use, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)
  
  ct <- coeftable(fit)
  out <- list()
  for (h in 0:max_lag) {
    vname <- paste0("PolZ_Agg_L", h)
    if (vname %in% rownames(ct)) {
      out[[length(out) + 1]] <- data.table(
        h = h,
        estimate = as.numeric(ct[vname, "Estimate"]),
        se = as.numeric(ct[vname, "Std. Error"]),
        pvalue = as.numeric(ct[vname, "Pr(>|z|)"])
      )
    } else {
      out[[length(out) + 1]] <- data.table(
        h = h, estimate = NA_real_, se = NA_real_, pvalue = NA_real_
      )
    }
  }
  res <- rbindlist(out, use.names = TRUE)
  res[, n := nrow(dt_use)]
  res[, n_country := uniqueN(dt_use$ISO)]
  return(res)
}

n_total <- nrow(windows_all) * length(DBS) * length(TRADE_VARS) * length(LAG_ORDERS)
pb <- txtProgressBar(min = 0, max = n_total, style = 3)
prog <- 0
results <- list()

for (wi in seq_len(nrow(windows_all))) {
  w <- windows_all[wi]
  dt_w <- panel_full[YearMonth >= w$window_start & YearMonth <= w$window_end]
  
  for (db_label in DBS) {
    dt_db <- dt_w[db == db_label]
    if (nrow(dt_db) == 0) {
      prog <- prog + length(TRADE_VARS) * length(LAG_ORDERS)
      setTxtProgressBar(pb, prog)
      next
    }
    
    for (trade in TRADE_VARS) {
      for (max_lag in LAG_ORDERS) {
        prog <- prog + 1
        setTxtProgressBar(pb, prog)
        
        res <- run_one_dl(dt_db, trade, max_lag)
        if (is.null(res)) next
        
        res[, window_id := w$window_id]
        res[, window_length := w$window_length]
        res[, window_midpoint := w$window_midpoint]
        res[, db := db_label]
        res[, trade := trade]
        res[, lag_order := max_lag]
        results[[length(results) + 1]] <- res
      }
    }
  }
}
close(pb)

coefs <- rbindlist(results, use.names = TRUE, fill = TRUE)
fwrite(coefs, file.path(OUT_DIR, "robustness_window_lag_coefficients.csv"))
cat(sprintf("✓ robustness_window_lag_coefficients.csv 已保存 (%d 行)\n", nrow(coefs)))

# ----------------------------------------------------------------------------
# 4) 计算响应速度指标
# ----------------------------------------------------------------------------
cat("[4/5] 计算窗口/滞后阶数稳健性指标...\n")

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

metrics <- coefs[, compute_metrics(.SD),
                 by = .(window_length, window_id, window_midpoint, db, trade, lag_order)]
fwrite(metrics, file.path(OUT_DIR, "robustness_window_lag_metrics.csv"))
cat(sprintf("✓ robustness_window_lag_metrics.csv 已保存 (%d 行)\n", nrow(metrics)))

# 汇总：各配置下平均响应滞后的均值/标准差
summary_dt <- metrics[!is.na(avg_response_lag), .(
  mean_avg_lag = mean(avg_response_lag, na.rm = TRUE),
  sd_avg_lag = sd(avg_response_lag, na.rm = TRUE),
  median_avg_lag = median(avg_response_lag, na.rm = TRUE),
  mean_peak_lag = mean(peak_lag, na.rm = TRUE),
  n_window = .N
), by = .(window_length, lag_order, db, trade)]
fwrite(summary_dt, file.path(OUT_DIR, "robustness_window_lag_summary.csv"))
cat(sprintf("✓ robustness_window_lag_summary.csv 已保存 (%d 行)\n", nrow(summary_dt)))
print(summary_dt)

# 与基准配置（窗口 60、滞后 6）的相关性
baseline_metrics <- metrics[window_length == 60 & lag_order == 6,
                            .(window_midpoint, db, trade, baseline_lag = avg_response_lag)]
corr_dt <- merge(metrics, baseline_metrics, by = c("window_midpoint", "db", "trade"), all.x = TRUE)
corr_summary <- corr_dt[!is.na(avg_response_lag) & !is.na(baseline_lag), .(
  r = cor(avg_response_lag, baseline_lag, use = "pairwise.complete.obs"),
  n = sum(complete.cases(avg_response_lag, baseline_lag))
), by = .(window_length, lag_order, db, trade)]
fwrite(corr_summary, file.path(OUT_DIR, "robustness_window_lag_vs_baseline.csv"))
cat(sprintf("✓ robustness_window_lag_vs_baseline.csv 已保存 (%d 行)\n", nrow(corr_summary)))

# ----------------------------------------------------------------------------
# 5) 可视化
# ----------------------------------------------------------------------------
cat("[5/5] 绘制窗口/滞后阶数稳健性图...\n")

plot_dt <- metrics[!is.na(avg_response_lag)]
plot_dt[, trade_label := factor(trade,
                                 levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                                 labels = c("总贸易", "出口", "进口"))]
plot_dt[, lag_label := factor(lag_order, levels = c(3, 6, 12),
                               labels = c("L = 3", "L = 6", "L = 12"))]
plot_dt[, window_label := factor(window_length, levels = c(36, 60, 84),
                                  labels = c("36 个月", "60 个月", "84 个月"))]

p1 <- ggplot(plot_dt, aes(x = window_midpoint, y = avg_response_lag,
                           color = lag_label, group = lag_label)) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 0.9) +
  facet_grid(trade_label ~ db, scales = "free_y") +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "窗口长度与滞后阶数稳健性：滚动窗口平均响应滞后",
    subtitle = "比较窗口长度 36/60/84 个月与分布滞后阶数 L3/L6/L12",
    x = "窗口中点年份",
    y = "平均响应滞后（月）",
    color = "滞后阶数"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 8),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 6)
  )

ggsave(file.path(FIG_DIR, "fig03_window_lag_robustness.png"), p1, width = 14, height = 10, dpi = 300)
cat("✓ fig03_window_lag_robustness.png\n")

# 汇总热力图：行 = 窗口长度，列 = 滞后阶数，分面 db × trade
p2 <- ggplot(summary_dt, aes(x = factor(lag_order), y = factor(window_length),
                                fill = mean_avg_lag)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", mean_avg_lag)), size = 2.5, color = "black") +
  facet_grid(trade ~ db) +
  scale_fill_gradient2(low = "#2166ac", mid = "#f7f7f7", high = "#b2182b", midpoint = 3,
                       name = "平均响应滞后") +
  labs(
    title = "窗口长度 × 滞后阶数：平均响应滞后热力图",
    x = "分布滞后阶数",
    y = "窗口长度（月）"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 8),
    axis.text.x = element_text(size = 8),
    axis.text.y = element_text(size = 8)
  )

ggsave(file.path(FIG_DIR, "fig04_window_lag_heatmap.png"), p2, width = 14, height = 10, dpi = 300)
cat("✓ fig04_window_lag_heatmap.png\n")

cat("窗口长度与滞后阶数稳健性分析完成。\n")
