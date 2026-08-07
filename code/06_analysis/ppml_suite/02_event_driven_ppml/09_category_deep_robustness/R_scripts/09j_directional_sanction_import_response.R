# 09j_directional_sanction_import_response.R

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

# 17 类当期变量（控制用）
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$|_F[0-9]+$", cat_cols)]
cat_cols <- setdiff(cat_cols, c("Cat_科技管制/出口限制", "Cat_经贸制裁/关税壁垒"))  # 用方向化变量替代原始变量

# 方向化制裁变量
dir_vars <- c("Cat_科技管制_对华", "Cat_科技管制_对伙伴",
              "Cat_经贸制裁_对华", "Cat_经贸制裁_对伙伴",
              "Cat_经贸制裁_多边", "Cat_经贸制裁_模糊")
dir_vars <- dir_vars[dir_vars %in% names(panel_ev)]

results <- list()

cat("[2/2] 跑方向化制裁效应回归...\n")

# 模型 1：仅方向化制裁变量 + 控制
for (trade in TRADE_VARS) {
  dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  
  formula_str <- sprintf("%s ~ %s + %s + %s | ISO + YearMonth",
                         trade,
                         paste(sprintf("`%s`", dir_vars), collapse = " + "),
                         paste(sprintf("`%s`", cat_cols), collapse = " + "),
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
  
  for (v in dir_vars) {
    if (v %in% rownames(ct)) {
      results[[length(results) + 1]] <- data.table(
        model = "方向化制裁 + 17类控制",
        trade = trade,
        variable = v,
        estimate = as.numeric(ct[v, "Estimate"]),
        se = as.numeric(ct[v, "Std. Error"]),
        pvalue = as.numeric(ct[v, "Pr(>|z|)"]),
        n = nrow(dt_fit),
        n_country = uniqueN(dt_fit$ISO)
      )
    }
  }
}

# 模型 2：方向化制裁 + 正负中性事件，检验是否被一般负向事件吸收
for (trade in TRADE_VARS) {
  dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  
  formula_str <- sprintf("%s ~ %s + Event_Positive + Event_Negative + Event_Neutral + %s + %s | ISO + YearMonth",
                         trade,
                         paste(sprintf("`%s`", dir_vars), collapse = " + "),
                         paste(sprintf("`%s`", cat_cols), collapse = " + "),
                         paste(CONTROLS, collapse = " + "))
  
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  
  if (is.null(fit)) next
  ct <- coeftable(fit)
  
  for (v in dir_vars) {
    if (v %in% rownames(ct)) {
      results[[length(results) + 1]] <- data.table(
        model = "方向化制裁 + 正负中性 + 17类控制",
        trade = trade,
        variable = v,
        estimate = as.numeric(ct[v, "Estimate"]),
        se = as.numeric(ct[v, "Std. Error"]),
        pvalue = as.numeric(ct[v, "Pr(>|z|)"]),
        n = nrow(dt_fit),
        n_country = uniqueN(dt_fit$ISO)
      )
    }
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "09j_directional_sanction_import_response.csv"))
cat(sprintf("✓ 09j_directional_sanction_import_response.csv 已保存 (%d 行)\n", nrow(out)))
print(out[order(model, trade, pvalue)])
