# 05_run_event_irf.R

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

HORIZONS <- c(0, 1, 3, 6, 12)

cat("[2/2] 跑事件 IRF...\n")
results <- list()

# ---- 正/负/中性事件 IRF ----
for (trade in TRADE_VARS) {
  for (h in HORIZONS) {
    pos_var <- if (h == 0) "Event_Positive" else paste0("Event_Positive_L", h)
    neg_var <- if (h == 0) "Event_Negative" else paste0("Event_Negative_L", h)
    neu_var <- if (h == 0) "Event_Neutral" else paste0("Event_Neutral_L", h)
    
    if (!all(c(pos_var, neg_var, neu_var) %in% names(panel_ev))) next
    
    dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
    dt_fit <- dt_fit[!is.na(get(pos_var)) & !is.na(get(neg_var)) & !is.na(get(neu_var))]
    
    fit <- tryCatch(
      fepois(as.formula(sprintf("%s ~ %s + %s + %s + %s | ISO + YearMonth",
                                trade, pos_var, neg_var, neu_var,
                                paste(CONTROLS, collapse = " + "))),
             data = dt_fit, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    
    if (is.null(fit)) next
    ct <- coeftable(fit)
    
    for (v in c(pos_var, neg_var, neu_var)) {
      if (v %in% rownames(ct)) {
        results[[length(results) + 1]] <- data.table(
          type = "valence",
          group = gsub("_L[0-9]+$", "", v),
          trade = trade,
          horizon = h,
          estimate = as.numeric(ct[v, "Estimate"]),
          se = as.numeric(ct[v, "Std. Error"]),
          pval = as.numeric(ct[v, "Pr(>|z|)"])
        )
      }
    }
  }
}

# ---- 4 类访问 IRF（仅总贸易） ----
for (h in HORIZONS) {
  visit_vars_h <- sapply(VISIT_VARS, function(v) if (h == 0) v else paste0(v, "_L", h))
  if (!all(visit_vars_h %in% names(panel_ev))) next
  
  dt_fit <- panel_ev[!is.na(Trade_Total) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  for (v in visit_vars_h) dt_fit <- dt_fit[!is.na(get(v))]
  
  fit <- tryCatch(
    fepois(as.formula(sprintf("Trade_Total ~ %s + %s | ISO + YearMonth",
                              paste(visit_vars_h, collapse = " + "),
                              paste(CONTROLS, collapse = " + "))),
           data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  
  if (is.null(fit)) next
  ct <- coeftable(fit)
  
  for (v in visit_vars_h) {
    if (v %in% rownames(ct)) {
      g <- gsub("_L[0-9]+$", "", v)
      results[[length(results) + 1]] <- data.table(
        type = "visit",
        group = g,
        trade = "Trade_Total",
        horizon = h,
        estimate = as.numeric(ct[v, "Estimate"]),
        se = as.numeric(ct[v, "Std. Error"]),
        pval = as.numeric(ct[v, "Pr(>|z|)"])
      )
    }
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
out[, ci_lower := estimate - 1.96 * se]
out[, ci_upper := estimate + 1.96 * se]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "05_event_irf.csv"))
cat(sprintf("✓ 05_event_irf.csv 已保存 (%d 行)\n", nrow(out)))
print(out[type == "valence" & group == "Event_Negative"])
