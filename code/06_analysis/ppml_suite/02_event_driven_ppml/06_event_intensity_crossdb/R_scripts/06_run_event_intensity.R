# 06_run_event_intensity.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/2] 读取事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# 将 NA 的 Delta 填充为 0（非事件月强度为 0）
for (db in DBS) {
  col <- paste0("Delta_", db)
  if (col %in% names(panel_ev)) {
    panel_ev[, (col) := ifelse(is.na(get(col)), 0, get(col))]
  }
}

cat("[2/2] 跑事件强度回归...\n")
res_cross <- list()
res_dose <- list()

for (db in DBS) {
  delta_col <- paste0("Delta_", db)
  if (!(delta_col %in% names(panel_ev))) next
  
  for (trade in TRADE_VARS) {
    dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
    dt_fit <- dt_fit[!is.na(get(delta_col))]
    
    # 模型 1：连续强度变量（不再加入 Event_Positive/Negative，避免与 Delta 共线）
    f1 <- tryCatch(
      fepois(as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth",
                                trade, delta_col, paste(CONTROLS, collapse = " + "))),
             data = dt_fit, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    
    if (!is.null(f1)) {
      ct <- coeftable(f1)
      if (delta_col %in% rownames(ct)) {
        res_cross[[length(res_cross) + 1]] <- data.table(
          db = db, trade = trade,
          variable = delta_col,
          estimate = as.numeric(ct[delta_col, "Estimate"]),
          se = as.numeric(ct[delta_col, "Std. Error"]),
          pval = as.numeric(ct[delta_col, "Pr(>|z|)"])
        )
      }
    }
    
    # 模型 2：剂量反应——仅使用事件月，按 |Delta| 三分位
    dt_dose <- dt_fit[get(delta_col) != 0]
    if (nrow(dt_dose) < 30) next
    abs_delta <- abs(dt_dose[[delta_col]])
    q <- quantile(abs_delta, probs = c(0, 1/3, 2/3, 1), na.rm = TRUE)
    if (any(duplicated(q))) next  # 分位重复则跳过
    
    dt_dose[, dose := cut(abs(get(delta_col)), breaks = q,
                          labels = c("Low", "Medium", "High"), include.lowest = TRUE)]
    dt_dose[, dose_medium := as.integer(dose == "Medium")]
    dt_dose[, dose_high := as.integer(dose == "High")]
    
    f2 <- tryCatch(
      fepois(as.formula(sprintf("%s ~ dose_medium + dose_high + %s | ISO + YearMonth",
                                trade, paste(CONTROLS, collapse = " + "))),
             data = dt_dose, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    
    if (!is.null(f2)) {
      ct2 <- coeftable(f2)
      for (v in c("dose_medium", "dose_high")) {
        if (v %in% rownames(ct2)) {
          res_dose[[length(res_dose) + 1]] <- data.table(
            db = db, trade = trade,
            dose = gsub("dose_", "", v),
            estimate = as.numeric(ct2[v, "Estimate"]),
            se = as.numeric(ct2[v, "Std. Error"]),
            pval = as.numeric(ct2[v, "Pr(>|z|)"])
          )
        }
      }
    }
  }
}

out_cross <- rbindlist(res_cross, use.names = TRUE)
if (nrow(out_cross) > 0) {
  out_cross[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
  out_cross[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]
}

out_dose <- rbindlist(res_dose, use.names = TRUE)
if (nrow(out_dose) > 0) {
  out_dose[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
  out_dose[, dose := factor(dose, levels = c("medium", "high"), labels = c("中强度", "高强度"))]
  out_dose[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]
}

fwrite(out_cross, file.path(OUT_DIR, "06_cross_db_validation.csv"))
fwrite(out_dose, file.path(OUT_DIR, "06_dose_response.csv"))
cat(sprintf("✓ 06_cross_db_validation.csv 已保存 (%d 行)\n", nrow(out_cross)))
cat(sprintf("✓ 06_dose_response.csv 已保存 (%d 行)\n", nrow(out_dose)))
print(out_cross)
print(out_dose)
