# 01_run_baseline_ppml.R

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

# 确保月份为日期格式
panel_ev[, YearMonth := as.Date(YearMonth)]

cat("[2/2] 跑基准 PPML...\n")
results <- list()

for (trade in TRADE_VARS) {
  dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  
  formula_str <- sprintf("%s ~ Event_Positive + Event_Negative + Event_Neutral + %s | ISO + YearMonth",
                         trade, paste(CONTROLS, collapse = " + "))
  
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  
  if (is.null(fit)) next
  
  coefs <- coeftable(fit)
  vars <- c("Event_Positive", "Event_Negative", "Event_Neutral")
  
  for (v in vars) {
    if (v %in% rownames(coefs)) {
      results[[length(results) + 1]] <- data.table(
        trade = trade,
        variable = v,
        estimate = coefs[v, "Estimate"],
        se = coefs[v, "Std. Error"],
        z = coefs[v, "z value"],
        pvalue = coefs[v, "Pr(>|z|)"],
        n = nrow(dt_fit),
        n_country = uniqueN(dt_fit$ISO)
      )
    }
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "01_baseline_event_effects.csv"))
cat(sprintf("✓ 01_baseline_event_effects.csv 已保存 (%d 行)\n", nrow(out)))
print(out)
