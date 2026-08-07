# 09k_directional_sanction_irf.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/2] 读取带方向化制裁变量的事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_with_directional_sanctions.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]
panel_ev <- panel_ev[order(ISO, YearMonth)]

# 生成领先项（预趋势）
HORIZONS <- c(-3, -2, -1, 0, 1, 3, 6, 12)
KEY_VARS <- c("Cat_科技管制_对华", "Cat_经贸制裁_对华")

for (v in KEY_VARS) {
  if (!(v %in% names(panel_ev))) next
  for (h in 1:3) {
    panel_ev[, (paste0(v, "_F", h)) := shift(get(v), n = h, type = "lead"), by = ISO]
  }
}

results <- list()

cat("[2/2] 跑方向化制裁 IRF...\n")

for (trade in TRADE_VARS) {
  for (v in KEY_VARS) {
    if (!(v %in% names(panel_ev))) next
    cat(sprintf("  %s -> %s\n", v, trade))
    
    for (h in HORIZONS) {
      var_h <- if (h < 0) paste0(v, "_F", abs(h)) else if (h == 0) v else paste0(v, "_L", h)
      if (!(var_h %in% names(panel_ev))) next
      
      dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(get(var_h))]
      for (c in CONTROLS) dt_fit <- dt_fit[!is.na(get(c))]
      
      formula_str <- sprintf("%s ~ `%s` + %s | ISO + YearMonth",
                             trade, var_h, paste(CONTROLS, collapse = " + "))
      
      fit <- tryCatch(
        fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
        error = function(e) NULL
      )
      
      if (is.null(fit)) next
      ct <- coeftable(fit)
      if (!(var_h %in% rownames(ct))) next
      
      est <- as.numeric(ct[var_h, "Estimate"])
      se  <- as.numeric(ct[var_h, "Std. Error"])
      p   <- as.numeric(ct[var_h, "Pr(>|z|)"])
      
      results[[length(results) + 1]] <- data.table(
        base_var = v,
        trade = trade,
        horizon = h,
        estimate = est,
        se = se,
        pvalue = p,
        ci_lower = est - 1.96 * se,
        ci_upper = est + 1.96 * se,
        n = nrow(dt_fit)
      )
    }
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "09k_directional_sanction_irf.csv"))
cat(sprintf("✓ 09k_directional_sanction_irf.csv 已保存 (%d 行)\n", nrow(out)))
print(out[, .(base_var, trade_label, horizon, estimate, se, pvalue, sig)])
