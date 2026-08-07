# 03_run_seventeen_categories.R

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

# 找出 17 类变量（排除高频参照组与滞后项）
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$", cat_cols)]  # 仅保留当期
cat_names <- gsub("^Cat_", "", cat_cols)
cat_summary <- panel_ev[, lapply(.SD, sum), .SDcols = cat_cols]
cat_freq <- data.table(category = cat_names, count = as.numeric(cat_summary[1]))
ref_cat <- cat_freq[which.max(count), category]  # 以频数最高类为参照
cat(sprintf("  参照组：%s（%d 次）\n", ref_cat, cat_freq[which.max(count), count]))

# 构造回归变量（去掉参照组）
model_cols <- setdiff(cat_cols, paste0("Cat_", ref_cat))

cat("[2/2] 跑 17 类 PPML...\n")
results <- list()

for (trade in TRADE_VARS) {
  dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  
  formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                         trade,
                         paste(sprintf("`%s`", model_cols), collapse = " + "),
                         paste(CONTROLS, collapse = " + "))
  
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) {
      cat(sprintf("  错误 (%s): %s\n", trade, e$message))
      NULL
    }
  )
  
  if (is.null(fit)) {
    cat(sprintf("  %s 拟合失败\n", trade))
    next
  }
  
  ct <- coeftable(fit)
  for (v in model_cols) {
    if (v %in% rownames(ct)) {
      cn <- gsub("^Cat_", "", v)
      results[[length(results) + 1]] <- data.table(
        trade = trade,
        category = cn,
        estimate = as.numeric(ct[v, "Estimate"]),
        se = as.numeric(ct[v, "Std. Error"]),
        z = as.numeric(ct[v, "z value"]),
        pval = as.numeric(ct[v, "Pr(>|z|)"]),
        n = nrow(dt_fit),
        n_country = uniqueN(dt_fit$ISO)
      )
    }
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, pval := as.numeric(pval)]
out[, estimate := as.numeric(estimate)]
out[, se := as.numeric(se)]
out[, z := as.numeric(z)]
out[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

# 加入英文名称与频数
out[, event_category_en := map_category_cn2en(category)]
out <- merge(out, cat_freq, by.x = "category", by.y = "category", all.x = TRUE)

fwrite(out, file.path(OUT_DIR, "03_seventeen_category_effects.csv"))
cat(sprintf("✓ 03_seventeen_category_effects.csv 已保存 (%d 行)\n", nrow(out)))
print(out[order(pval)][1:20])
