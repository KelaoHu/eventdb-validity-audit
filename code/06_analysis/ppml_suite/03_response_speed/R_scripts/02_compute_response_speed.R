# 02_compute_response_speed.R

rm(list = ls())

pkgs <- c("data.table", "dplyr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
MID_DIR <- file.path(TEST_DIR, "中间数据")

cat("[1/2] 读取窗口系数与窗口定义...\n")
coef_dt <- fread(file.path(OUT_DIR, "window_coefficients.csv"), encoding = "UTF-8")
windows <- fread(file.path(MID_DIR, "windows.csv"), encoding = "UTF-8")
windows[, window_start := as.Date(window_start)]
windows[, window_end := as.Date(window_end)]
windows[, window_midpoint := as.Date(window_midpoint)]

cat("[2/2] 计算响应速度指标...\n")

compute_metrics <- function(dt) {
  # dt 应包含一个窗口、一个 db、一个 trade、一个 pol_var 的 L0-L6 系数
  dt <- dt[order(h)]
  est <- dt$estimate
  pv <- dt$pvalue
  
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
  h_vec <- dt$h
  
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

metrics <- coef_dt[, compute_metrics(.SD), by = .(window_id, db, trade, pol_var)]
metrics <- merge(metrics, windows[, .(window_id, window_start, window_end, window_midpoint, window_label)], by = "window_id", all.x = TRUE)

metrics[, trade_label := factor(trade,
                                levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                                labels = c("总贸易", "出口", "进口"))]
metrics[, pol_label := factor(pol_var,
                               levels = c("Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"),
                               labels = c("综合指数", "中国→伙伴", "伙伴→中国"))]

fwrite(metrics, file.path(OUT_DIR, "response_speed_metrics.csv"))
cat(sprintf("✓ response_speed_metrics.csv 已保存 (%d 行)\n", nrow(metrics)))
print(metrics[!is.na(avg_response_lag)][order(db, trade, pol_var, window_id)])

# 同时生成一个宽格式便于阅读
wide <- dcast(metrics, window_id + window_label + db + trade + trade_label ~ pol_var,
              value.var = c("avg_response_lag", "immediate_share", "peak_lag", "sig_lags_count"))
fwrite(wide, file.path(OUT_DIR, "response_speed_metrics_wide.csv"))
cat(sprintf("✓ response_speed_metrics_wide.csv 已保存 (%d 行)\n", nrow(wide)))
