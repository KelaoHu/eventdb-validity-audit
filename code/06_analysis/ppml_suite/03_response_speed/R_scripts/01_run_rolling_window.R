# 01_run_rolling_window.R

rm(list = ls())

pkgs <- c("fixest", "data.table", "dplyr", "readr", "tidyr", "ggplot2", "stringr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
MID_DIR <- file.path(TEST_DIR, "中间数据")
OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取准备好的面板与窗口定义...\n")
panel_db <- fread(file.path(MID_DIR, "panel_with_scores_and_lags.csv"), encoding = "UTF-8")
setnames(panel_db, sub("^\ufeff", "", names(panel_db)))
panel_db[, YearMonth := as.Date(YearMonth)]

windows <- fread(file.path(MID_DIR, "windows.csv"), encoding = "UTF-8")
windows[, window_start := as.Date(window_start)]
windows[, window_end := as.Date(window_end)]

DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
POL_VARS <- c("Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN")
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
HORIZONS <- 0:6
MIN_OBS <- 100

# Tsinghua 只有 Pol_Agg
valid_pol <- function(db, pol) {
  if (db == "Tsinghua" && pol != "Pol_Agg") return(FALSE)
  return(TRUE)
}

run_one_regression <- function(dt_fit, trade, pol, label) {
  # 构造 RHS：L0-L6
  lag_vars <- paste0(pol, "_L", HORIZONS)
  if (!all(lag_vars %in% names(dt_fit))) return(NULL)
  
  # 删除 RHS/controls 存在 NA 的行
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
    vname <- paste0(pol, "_L", h)
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

# ----------------------------------------------------------------------------
# 2) 滚动窗口回归
# ----------------------------------------------------------------------------
cat("[2/3] 滚动窗口回归（约 20 窗口 × 4 库 × 3 贸易 × 3 政治变量）...\n")
results <- list()
n_total <- nrow(windows) * length(DBS) * length(TRADE_VARS) * length(POL_VARS)
cat(sprintf("预计组合数：%d\n", n_total))

pb <- txtProgressBar(min = 0, max = n_total, style = 3)
prog <- 0

for (wi in seq_len(nrow(windows))) {
  w <- windows[wi]
  dt_w <- panel_db[YearMonth >= w$window_start & YearMonth <= w$window_end]
  
  for (db_label in DBS) {
    dt_db <- dt_w[db == db_label]
    if (nrow(dt_db) == 0) {
      prog <- prog + length(TRADE_VARS) * length(POL_VARS)
      setTxtProgressBar(pb, prog)
      next
    }
    
    for (trade in TRADE_VARS) {
      for (pol in POL_VARS) {
        prog <- prog + 1
        setTxtProgressBar(pb, prog)
        
        if (!valid_pol(db_label, pol)) next
        
        res <- run_one_regression(dt_db, trade, pol, paste(db_label, w$window_id, trade, pol, sep = "_"))
        if (is.null(res)) next
        
        res[, window_id := w$window_id]
        res[, db := db_label]
        res[, trade := trade]
        res[, pol_var := pol]
        results[[length(results) + 1]] <- res
      }
    }
  }
}
close(pb)

coef_dt <- rbindlist(results, use.names = TRUE, fill = TRUE)
fwrite(coef_dt, file.path(OUT_DIR, "window_coefficients.csv"))
cat(sprintf("✓ window_coefficients.csv 已保存 (%d 行)\n", nrow(coef_dt)))

# ----------------------------------------------------------------------------
# 3) 全样本基准回归
# ----------------------------------------------------------------------------
cat("[3/3] 全样本基准回归...\n")
baseline_results <- list()

for (db_label in DBS) {
  dt_db <- panel_db[db == db_label]
  if (nrow(dt_db) == 0) next
  
  for (trade in TRADE_VARS) {
    for (pol in POL_VARS) {
      if (!valid_pol(db_label, pol)) next
      res <- run_one_regression(dt_db, trade, pol, paste(db_label, "full", trade, pol, sep = "_"))
      if (is.null(res)) next
      res[, db := db_label]
      res[, trade := trade]
      res[, pol_var := pol]
      baseline_results[[length(baseline_results) + 1]] <- res
    }
  }
}

baseline_dt <- rbindlist(baseline_results, use.names = TRUE, fill = TRUE)
baseline_dt[, window_id := 0]
baseline_dt[, window_label := "Full Sample"]
fwrite(baseline_dt, file.path(OUT_DIR, "full_sample_baseline.csv"))
cat(sprintf("✓ full_sample_baseline.csv 已保存 (%d 行)\n", nrow(baseline_dt)))

cat("滚动窗口回归完成。\n")
