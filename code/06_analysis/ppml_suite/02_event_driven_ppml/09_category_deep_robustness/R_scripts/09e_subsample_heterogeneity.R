# 09e_subsample_heterogeneity.R

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

# 17 类变量（参照组：高层互访）
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$|_F[0-9]+$", cat_cols)]
cat_summary <- panel_ev[, lapply(.SD, sum), .SDcols = cat_cols]
cat_freq <- data.table(category = gsub("^Cat_", "", cat_cols), count = as.numeric(cat_summary[1]))
ref_cat <- cat_freq[which.max(count), category]
model_cols <- setdiff(cat_cols, paste0("Cat_", ref_cat))

KEY_CATS <- c("人文交流合作", "战略定位负面", "经贸互利合作")

# ============================================================================
# 2. 定义分样本变量
# ============================================================================
cat("[2/4] 构建分样本标签...\n")

# 发达国家
developed <- c("US", "JP", "DE", "GB", "FR", "IT", "CA", "AU", "ES", "NL", "BE", "KR", "SG")
panel_ev[, developed := as.integer(ISO %in% developed)]

# 地理区域
panel_ev[, region := fcase(
  ISO %in% c("JP", "KR", "IN", "ID", "TH", "MY", "PH", "VN", "SG", "AE", "SA"), "Asia_MiddleEast",
  ISO %in% c("DE", "GB", "FR", "IT", "ES", "NL", "BE", "RU"), "Europe",
  ISO %in% c("US", "CA", "MX", "BR"), "Americas",
  default = "Other"
)]

# 贸易依存度：按该国对华平均月度总贸易三分位数
avg_trade <- panel_ev[, .(avg_trade = mean(Trade_Total, na.rm = TRUE)), by = ISO]
qts <- quantile(avg_trade$avg_trade, probs = c(1/3, 2/3), na.rm = TRUE)
avg_trade[, trade_dep := fcase(
  avg_trade <= qts[1], "low",
  avg_trade <= qts[2], "medium",
  default = "high"
)]
panel_ev <- merge(panel_ev, avg_trade[, .(ISO, trade_dep)], by = "ISO", all.x = TRUE)

# 定义分样本维度
dims <- list(
  list(name = "developed", var = "developed", labels = c("0" = "发展中", "1" = "发达")),
  list(name = "FTA", var = "FTA_Dummy", labels = c("0" = "无 FTA", "1" = "有 FTA")),
  list(name = "region", var = "region", labels = NULL),
  list(name = "trade_dep", var = "trade_dep", labels = NULL)
)

results <- list()

cat("[3/4] 分样本回归与 Wald 检验...\n")

for (trade in TRADE_VARS) {
  dt_base <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  
  for (cn in KEY_CATS) {
    v <- paste0("Cat_", cn)
    if (!(v %in% model_cols)) next
    
    cat(sprintf("  %s -> %s\n", cn, trade))
    
    # 全样本系数（参照）
    other_cats <- setdiff(model_cols, v)
    formula_full <- sprintf("%s ~ `%s` + %s + %s | ISO + YearMonth",
                            trade, v,
                            paste(sprintf("`%s`", other_cats), collapse = " + "),
                            paste(CONTROLS, collapse = " + "))
    fit_full <- tryCatch(
      fepois(as.formula(formula_full), data = dt_base, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    
    if (!is.null(fit_full) && v %in% rownames(coeftable(fit_full))) {
      ct <- coeftable(fit_full)
      results[[length(results) + 1]] <- data.table(
        dimension = "full_sample",
        group = "all",
        trade = trade,
        category = cn,
        estimate = as.numeric(ct[v, "Estimate"]),
        se = as.numeric(ct[v, "Std. Error"]),
        pvalue = as.numeric(ct[v, "Pr(>|z|)"]),
        n = nrow(dt_base),
        n_country = uniqueN(dt_base$ISO),
        note = "全样本"
      )
    }
    
    # 各维度分样本
    for (dim in dims) {
      groups <- sort(unique(dt_base[[dim$var]]))
      if (length(groups) < 2) next
      
      group_fits <- list()
      group_est <- list()
      
      for (g in groups) {
        dt_g <- dt_base[get(dim$var) == g]
        if (nrow(dt_g) == 0) next
        
        fit_g <- tryCatch(
          fepois(as.formula(formula_full), data = dt_g, cluster = ~ISO, glm.iter = 100),
          error = function(e) NULL
        )
        
        if (!is.null(fit_g) && v %in% rownames(coeftable(fit_g))) {
          ct_g <- coeftable(fit_g)
          g_label <- if (!is.null(dim$labels) && as.character(g) %in% names(dim$labels)) dim$labels[[as.character(g)]] else as.character(g)
          group_fits[[g_label]] <- fit_g
          group_est[[g_label]] <- as.numeric(ct_g[v, "Estimate"])
          
          results[[length(results) + 1]] <- data.table(
            dimension = dim$name,
            group = g_label,
            trade = trade,
            category = cn,
            estimate = as.numeric(ct_g[v, "Estimate"]),
            se = as.numeric(ct_g[v, "Std. Error"]),
            pvalue = as.numeric(ct_g[v, "Pr(>|z|)"]),
            n = nrow(dt_g),
            n_country = uniqueN(dt_g$ISO),
            note = sprintf("%s=%s", dim$name, g)
          )
        }
      }
      
      # 系数相等性 Wald 检验（仅两个组时）
      if (length(group_fits) == 2) {
        # 在全样本中加入交互项
        g_vals <- sort(unique(dt_base[[dim$var]]))
        if (length(g_vals) == 2) {
          gvar <- dim$var
          inter_name <- paste0(v, "_x_", gvar)
          dt_base[, (inter_name) := get(v) * get(gvar)]
          
          formula_inter <- sprintf("%s ~ `%s` + `%s` + %s + %s | ISO + YearMonth",
                                   trade, v, inter_name,
                                   paste(sprintf("`%s`", other_cats), collapse = " + "),
                                   paste(CONTROLS, collapse = " + "))
          fit_inter <- tryCatch(
            fepois(as.formula(formula_inter), data = dt_base, cluster = ~ISO, glm.iter = 100),
            error = function(e) NULL
          )
          
          if (!is.null(fit_inter) && inter_name %in% rownames(coeftable(fit_inter))) {
            w <- tryCatch(wald(fit_inter, inter_name), error = function(e) NULL)
            if (!is.null(w)) {
              p_wald <- if (is.list(w) && "p" %in% names(w)) as.numeric(w$p) else if (is.numeric(w)) as.numeric(w[1]) else NA_real_
              g_labels <- names(group_est)
              results[[length(results) + 1]] <- data.table(
                dimension = dim$name,
                group = paste(g_labels, collapse = " vs "),
                trade = trade,
                category = cn,
                estimate = NA_real_,
                se = NA_real_,
                pvalue = p_wald,
                n = nrow(dt_base),
                n_country = uniqueN(dt_base$ISO),
                note = "H0: 两组系数相等"
              )
            }
          }
          
          dt_base[, (inter_name) := NULL]
        }
      }
    }
  }
}

# ============================================================================
# 4. 保存与多重检验校正
# ============================================================================
out <- rbindlist(results, use.names = TRUE, fill = TRUE)

# 对分样本系数做 FDR 校正（按 dimension × trade）
out[!is.na(estimate), qvalue_bh := p.adjust(pvalue, method = "BH"), by = .(dimension, trade)]
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "09e_subsample_heterogeneity.csv"))
cat(sprintf("✓ 09e_subsample_heterogeneity.csv 已保存 (%d 行)\n", nrow(out)))

print(out[, .(dimension, group, trade_label, category, estimate, se, pvalue, qvalue_bh, sig, n, n_country)])
