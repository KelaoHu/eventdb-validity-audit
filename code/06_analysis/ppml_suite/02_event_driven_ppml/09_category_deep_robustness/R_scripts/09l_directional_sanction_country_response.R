# 09l_directional_sanction_country_response.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取带方向化制裁变量的事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_with_directional_sanctions.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# 国家特征标签
developed <- c("US", "JP", "DE", "GB", "FR", "IT", "CA", "AU", "ES", "NL", "BE", "KR", "SG")
panel_ev[, developed := as.integer(ISO %in% developed)]
panel_ev[, us_ally := as.integer(ISO %in% c("US", "JP", "AU", "CA", "GB", "KR", "DE", "FR", "IT", "ES", "NL", "BE"))]
panel_ev[, high_trade_dep := as.integer(ISO %in% c("AU", "BR", "KR", "JP", "DE", "MY", "TH", "VN", "SG", "SA", "AE", "IR", "MX"))]

KEY_VARS <- c("Cat_科技管制_对华", "Cat_经贸制裁_对华")
KEY_VARS <- KEY_VARS[KEY_VARS %in% names(panel_ev)]

results <- list()

cat("[2/3] 国家特征交互项回归...\n")

for (trade in c("Trade_Imports", "Trade_Exports", "Trade_Total")) {
  for (v in KEY_VARS) {
    # 交互变量
    inter_terms <- c(paste0(v, "_x_developed"), paste0(v, "_x_FTA"), paste0(v, "_x_us_ally"), paste0(v, "_x_high_dep"))
    panel_ev[, (paste0(v, "_x_developed")) := get(v) * developed]
    panel_ev[, (paste0(v, "_x_FTA")) := get(v) * FTA_Dummy]
    panel_ev[, (paste0(v, "_x_us_ally")) := get(v) * us_ally]
    panel_ev[, (paste0(v, "_x_high_dep")) := get(v) * high_trade_dep]
    
    dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
    
    formula_str <- sprintf("%s ~ `%s` + %s + %s | ISO + YearMonth",
                           trade, v,
                           paste(inter_terms, collapse = " + "),
                           paste(CONTROLS, collapse = " + "))
    
    fit <- tryCatch(
      fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    
    if (is.null(fit)) next
    ct <- coeftable(fit)
    
    for (term in c(v, inter_terms)) {
      if (term %in% rownames(ct)) {
        results[[length(results) + 1]] <- data.table(
          trade = trade,
          base_var = v,
          variable = term,
          estimate = as.numeric(ct[term, "Estimate"]),
          se = as.numeric(ct[term, "Std. Error"]),
          pvalue = as.numeric(ct[term, "Pr(>|z|)"]),
          n = nrow(dt_fit)
        )
      }
    }
  }
}

# ============================================================================
# 3. 事件描述性统计：各国事件发生次数与进口变化
# ============================================================================
cat("[3/3] 事件描述性统计...\n")

desc_stats <- list()
for (v in KEY_VARS) {
  event_rows <- panel_ev[get(v) == 1]
  if (nrow(event_rows) == 0) next
  
  # 计算事件当月进口同比变化（若可能）
  event_rows[, import_yoy := Trade_Imports - shift(Trade_Imports, n = 12, type = "lag"), by = ISO]
  
  desc_stats[[length(desc_stats) + 1]] <- event_rows[, .(
    base_var = v,
    ISO = ISO[1],
    Country = Country[1],
    n_events = .N,
    avg_import = mean(Trade_Imports, na.rm = TRUE),
    avg_import_yoy = mean(import_yoy, na.rm = TRUE)
  ), by = ISO]
}

desc_out <- rbindlist(desc_stats, use.names = TRUE, fill = TRUE)

# ============================================================================
# 4. 保存
# ============================================================================
out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "09l_directional_sanction_country_response.csv"))
fwrite(desc_out, file.path(OUT_DIR, "09l_directional_sanction_descriptive.csv"))
cat(sprintf("✓ 09l_directional_sanction_country_response.csv 已保存 (%d 行)\n", nrow(out)))
cat(sprintf("✓ 09l_directional_sanction_descriptive.csv 已保存 (%d 行)\n", nrow(desc_out)))
print(out[, .(trade_label, base_var, variable, estimate, se, pvalue, sig)])
