# 09a_reliability_seventeen_categories.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/4] 读取事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# 17 类当期变量
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$", cat_cols)]
cat_names <- gsub("^Cat_", "", cat_cols)

# 事件频数
cat_summary <- panel_ev[, lapply(.SD, sum), .SDcols = cat_cols]
cat_freq <- data.table(category = cat_names, count = as.numeric(cat_summary[1]))

# 参照组：高层互访（频数最高）
ref_cat <- cat_freq[which.max(count), category]
cat(sprintf("  参照组：%s（%d 次）\n", ref_cat, cat_freq[which.max(count), count]))

model_cols <- setdiff(cat_cols, paste0("Cat_", ref_cat))

# ============================================================================
# 2. 主回归 + 多重检验校正 + 小样本 t 校正
# ============================================================================
cat("[2/4] 跑 17 类主回归...\n")

results <- list()
G <- uniqueN(panel_ev$ISO)  # 聚类数
small_df <- max(G - 1, 1)

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
  
  if (is.null(fit)) next
  
  ct <- coeftable(fit)
  n_obs <- nrow(dt_fit)
  
  for (v in model_cols) {
    if (v %in% rownames(ct)) {
      cn <- gsub("^Cat_", "", v)
      est <- as.numeric(ct[v, "Estimate"])
      se  <- as.numeric(ct[v, "Std. Error"])
      z   <- as.numeric(ct[v, "z value"])
      p   <- as.numeric(ct[v, "Pr(>|z|)"])
      
      # 小样本 t_{G-1} 校正 p 值
      t_stat <- est / se
      p_t <- 2 * pt(-abs(t_stat), df = small_df)
      
      results[[length(results) + 1]] <- data.table(
        trade = trade,
        category = cn,
        estimate = est,
        se = se,
        z = z,
        pvalue = p,
        pvalue_t_g1 = p_t,
        n = n_obs,
        n_country = G,
        sparse = as.integer(cat_freq[category == cn, count] < 10)
      )
    }
  }
}

out <- rbindlist(results, use.names = TRUE)

# 补充被回归剔除的类别（共线性/无变异），保持输出完整
all_cats <- gsub("^Cat_", "", model_cols)
existing <- unique(out[, .(trade, category)])
full_grid <- data.table(expand.grid(trade = TRADE_VARS, category = all_cats, stringsAsFactors = FALSE))
missing <- full_grid[!existing, on = .(trade, category)]
if (nrow(missing) > 0) {
  missing[, `:=`(
    estimate = NA_real_, se = NA_real_, z = NA_real_, pvalue = NA_real_,
    pvalue_t_g1 = NA_real_, n = NA_integer_, n_country = G, sparse = NA_integer_,
    dropped = 1
  )]
  out <- rbind(out, missing, fill = TRUE)
} else {
  out[, dropped := 0]
}

# ============================================================================
# 3. FDR / Bonferroni 校正
# ============================================================================
cat("[3/4] 多重检验校正...\n")

# 按贸易变量分别校正
out[, qvalue_bh_by_trade := p.adjust(pvalue, method = "BH"), by = trade]
out[, pvalue_bonf_by_trade := p.adjust(pvalue, method = "bonferroni"), by = trade]

# 全体系数联合校正（51 个系数）
out[, qvalue_bh_joint := p.adjust(pvalue, method = "BH")]
out[, pvalue_bonf_joint := p.adjust(pvalue, method = "bonferroni")]

# 显著性标记（基于 FDR-by-trade 最宽松标准）
out[, sig_fdr := ifelse(qvalue_bh_by_trade < 0.01, "***",
                        ifelse(qvalue_bh_by_trade < 0.05, "**",
                               ifelse(qvalue_bh_by_trade < 0.10, "*", "")))]

out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]
out[, event_category_en := map_category_cn2en(category)]
out <- merge(out, cat_freq, by = "category", all.x = TRUE)

# ============================================================================
# 4. Leave-one-out 敏感度（仅对 FDR 显著或关键类别）
# ============================================================================
cat("[4/4] Leave-one-out 敏感度分析...\n")

key_cats <- unique(out[qvalue_bh_by_trade < 0.10 | category == "经贸互利合作", category])
loo_results <- list()

for (trade in TRADE_VARS) {
  for (cn in key_cats) {
    v <- paste0("Cat_", cn)
    if (!(v %in% model_cols)) next
    
    countries <- sort(unique(panel_ev$ISO))
    for (leave_iso in countries) {
      dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
      dt_fit <- dt_fit[ISO != leave_iso]
      
      formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                             trade,
                             paste(sprintf("`%s`", model_cols), collapse = " + "),
                             paste(CONTROLS, collapse = " + "))
      
      fit <- tryCatch(
        fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
        error = function(e) NULL
      )
      
      if (is.null(fit)) next
      ct <- coeftable(fit)
      if (v %in% rownames(ct)) {
        loo_results[[length(loo_results) + 1]] <- data.table(
          trade = trade,
          category = cn,
          leave_iso = leave_iso,
          estimate = as.numeric(ct[v, "Estimate"]),
          se = as.numeric(ct[v, "Std. Error"]),
          pvalue = as.numeric(ct[v, "Pr(>|z|)"])
        )
      }
    }
  }
}

loo_out <- rbindlist(loo_results, use.names = TRUE)

# 汇总 loo：符号变化次数、系数范围
loo_summary <- loo_out[, .(
  loo_n = .N,
  loo_pos = sum(estimate > 0, na.rm = TRUE),
  loo_neg = sum(estimate < 0, na.rm = TRUE),
  loo_min = min(estimate, na.rm = TRUE),
  loo_max = max(estimate, na.rm = TRUE)
), by = .(trade, category)]

out <- merge(out, loo_summary, by = c("trade", "category"), all.x = TRUE)

# ============================================================================
# 5. 保存
# ============================================================================
fwrite(out, file.path(OUT_DIR, "09a_reliability_category_effects.csv"))
cat(sprintf("✓ 09a_reliability_category_effects.csv 已保存 (%d 行)\n", nrow(out)))

# 打印关键结果
print(out[order(qvalue_bh_by_trade)][, .(trade_label, category, estimate, se, pvalue, pvalue_t_g1, qvalue_bh_by_trade, qvalue_bh_joint, sig_fdr, count, sparse)])
