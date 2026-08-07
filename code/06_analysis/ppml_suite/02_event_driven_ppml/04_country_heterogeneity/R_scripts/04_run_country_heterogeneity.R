# 04_run_country_heterogeneity.R

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

cat("[2/2] 构建国家-事件交互项并跑 PPML...\n")

countries <- sort(unique(panel_ev$ISO))
ref_country <- countries[1]  # 参照国

# 为每个国家生成交互项
for (cty in countries) {
  panel_ev[, (paste0("Pos_", cty)) := as.integer(ISO == cty) * Event_Positive]
  panel_ev[, (paste0("Neg_", cty)) := as.integer(ISO == cty) * Event_Negative]
}

# 回归变量（去掉参照国）
interact_vars <- c(
  paste0("Pos_", setdiff(countries, ref_country)),
  paste0("Neg_", setdiff(countries, ref_country))
)

results <- list()

for (trade in TRADE_VARS) {
  dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  
  formula_str <- sprintf("%s ~ Pos_%s + Neg_%s + %s + %s | ISO + YearMonth",
                         trade, ref_country, ref_country,
                         paste(interact_vars, collapse = " + "),
                         paste(CONTROLS, collapse = " + "))
  
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) {
      cat(sprintf("  错误 (%s): %s\n", trade, e$message))
      NULL
    }
  )
  
  if (is.null(fit)) next
  
  ct <- coeftable(fit)
  
  for (cty in countries) {
    vpos <- paste0("Pos_", cty)
    vneg <- paste0("Neg_", cty)
    cname <- unique(panel_ev[ISO == cty, Country])[1]
    
    bpos <- if (vpos %in% rownames(ct)) as.numeric(ct[vpos, "Estimate"]) else NA_real_
    bneg <- if (vneg %in% rownames(ct)) as.numeric(ct[vneg, "Estimate"]) else NA_real_
    sepos <- if (vpos %in% rownames(ct)) as.numeric(ct[vpos, "Std. Error"]) else NA_real_
    seneg <- if (vneg %in% rownames(ct)) as.numeric(ct[vneg, "Std. Error"]) else NA_real_
    ppos <- if (vpos %in% rownames(ct)) as.numeric(ct[vpos, "Pr(>|z|)"]) else NA_real_
    pneg <- if (vneg %in% rownames(ct)) as.numeric(ct[vneg, "Pr(>|z|)"]) else NA_real_
    
    results[[length(results) + 1]] <- data.table(
      ISO = cty, Country = cname, trade = trade,
      variable = "Event_Positive", estimate = bpos, se = sepos, pval = ppos
    )
    results[[length(results) + 1]] <- data.table(
      ISO = cty, Country = cname, trade = trade,
      variable = "Event_Negative", estimate = bneg, se = seneg, pval = pneg
    )
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

# 计算敏感度指数（仅总贸易）
sens <- dcast(out[trade == "Trade_Total"], ISO + Country ~ variable, value.var = "estimate")
sens[, sensitivity := Event_Negative - Event_Positive]
sens <- sens[!is.na(Event_Positive) & !is.na(Event_Negative)]
setorder(sens, -sensitivity)
out <- merge(out, sens[, .(ISO, sensitivity)], by = "ISO", all.x = TRUE)

fwrite(out, file.path(OUT_DIR, "04_country_heterogeneity.csv"))
cat(sprintf("✓ 04_country_heterogeneity.csv 已保存 (%d 行)\n", nrow(out)))
print(sens)
