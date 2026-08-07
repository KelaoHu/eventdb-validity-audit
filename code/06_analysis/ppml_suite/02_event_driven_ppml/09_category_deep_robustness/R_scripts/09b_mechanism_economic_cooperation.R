# 09b_mechanism_economic_cooperation.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取事件面板与事件库...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]
panel_ev <- panel_ev[order(ISO, YearMonth)]

# 读取原始事件库，检查是否有协议子标签
events <- load_events(ROOT_DIR)
subtag_cols <- intersect(c("event_type_original", "event_name", "description", "notes", "subtype"), names(events))
has_subtype <- length(subtag_cols) > 0
if (has_subtype) {
  cat("  事件库可用子标签列：", paste(subtag_cols, collapse = ", "), "\n")
} else {
  cat("  事件库无明确协议子标签列，跳过协议子类拆分。\n")
}

# 生成事前趋势变量（leads）
ECON_VAR <- "Cat_经贸互利合作"
for (h in 1:3) {
  panel_ev[, (paste0(ECON_VAR, "_F", h)) := shift(get(ECON_VAR), n = h, type = "lead"), by = ISO]
}

# 国事访问变量（合并中方与外方国事访问）
if (all(c("V_China_Outbound", "V_Partner_Inbound") %in% names(panel_ev))) {
  panel_ev[, V_StateVisit := as.integer(V_China_Outbound == 1 | V_Partner_Inbound == 1)]
} else {
  panel_ev[, V_StateVisit := 0]
}

# 17 类变量（参照组：高层互访）
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$|_F[0-9]+$", cat_cols)]
cat_summary <- panel_ev[, lapply(.SD, sum), .SDcols = cat_cols]
cat_freq <- data.table(category = gsub("^Cat_", "", cat_cols), count = as.numeric(cat_summary[1]))
ref_cat <- cat_freq[which.max(count), category]
model_cols <- setdiff(cat_cols, paste0("Cat_", ref_cat))

results <- list()

# ============================================================================
# 1. 事前趋势（leads）
# ============================================================================
cat("[2/3] 事前趋势检验...\n")
for (trade in TRADE_VARS) {
  lead_vars <- paste0(ECON_VAR, "_F", 1:3)
  dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  dt_fit <- dt_fit[complete.cases(dt_fit[, ..lead_vars])]
  
  formula_str <- sprintf("%s ~ %s + %s + %s | ISO + YearMonth",
                         trade,
                         paste(sprintf("`%s`", model_cols), collapse = " + "),
                         paste(lead_vars, collapse = " + "),
                         paste(CONTROLS, collapse = " + "))
  
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  
  if (is.null(fit)) next
  ct <- coeftable(fit)
  
  for (v in lead_vars) {
    if (v %in% rownames(ct)) {
      results[[length(results) + 1]] <- data.table(
        test = "pre_trend_lead",
        trade = trade,
        variable = v,
        estimate = as.numeric(ct[v, "Estimate"]),
        se = as.numeric(ct[v, "Std. Error"]),
        pvalue = as.numeric(ct[v, "Pr(>|z|)"]),
        n = nrow(dt_fit),
        note = "系数为经贸互利合作h期前的领先项"
      )
    }
  }
  
  # Wald 联合检验：所有 lead = 0
  w <- tryCatch(wald(fit, lead_vars), error = function(e) NULL)
  if (!is.null(w)) {
    p_wald <- if (is.list(w) && "p" %in% names(w)) as.numeric(w$p) else if (is.numeric(w)) as.numeric(w[1]) else NA_real_
    results[[length(results) + 1]] <- data.table(
      test = "pre_trend_joint_wald",
      trade = trade,
      variable = "joint_leads",
      estimate = NA_real_,
      se = NA_real_,
      pvalue = p_wald,
      n = nrow(dt_fit),
      note = "H0: 所有领先项系数同时为0"
    )
  }
}

# ============================================================================
# 2. 与国事访问的交互效应
# ============================================================================
cat("  与国事访问交互...\n")
if ("V_StateVisit" %in% names(panel_ev)) {
  panel_ev[, Econ_x_StateVisit := get(ECON_VAR) * V_StateVisit]
  
  for (trade in TRADE_VARS) {
    dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
    
    # 模型：包含主效应、访问主效应、交互项、其他类别、控制变量
    other_cats <- setdiff(model_cols, ECON_VAR)
    rhs_terms <- c(sprintf("`%s`", other_cats), sprintf("`%s`", ECON_VAR), "V_StateVisit", "Econ_x_StateVisit", CONTROLS)
    formula_str <- sprintf("%s ~ %s | ISO + YearMonth", trade, paste(rhs_terms, collapse = " + "))
    
    fit <- tryCatch(
      fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    
    if (is.null(fit)) next
    ct <- coeftable(fit)
    
    for (v in c(ECON_VAR, "Econ_x_StateVisit")) {
      if (v %in% rownames(ct)) {
        results[[length(results) + 1]] <- data.table(
          test = "interaction_state_visit",
          trade = trade,
          variable = v,
          estimate = as.numeric(ct[v, "Estimate"]),
          se = as.numeric(ct[v, "Std. Error"]),
          pvalue = as.numeric(ct[v, "Pr(>|z|)"]),
          n = nrow(dt_fit),
          note = ifelse(v == ECON_VAR, "单独经贸互利合作效应", "经贸互利合作 × 国事访问交互效应")
        )
      }
    }
  }
}

# ============================================================================
# 3. 与 FTA 的交互效应
# ============================================================================
cat("  与 FTA 交互...\n")
panel_ev[, Econ_x_FTA := get(ECON_VAR) * FTA_Dummy]

for (trade in TRADE_VARS) {
  dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  
  other_cats <- setdiff(model_cols, ECON_VAR)
  rhs_terms <- c(sprintf("`%s`", other_cats), sprintf("`%s`", ECON_VAR), "FTA_Dummy", "Econ_x_FTA", CONTROLS)
  formula_str <- sprintf("%s ~ %s | ISO + YearMonth", trade, paste(rhs_terms, collapse = " + "))
  
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  
  if (is.null(fit)) next
  ct <- coeftable(fit)
  
  for (v in c(ECON_VAR, "Econ_x_FTA")) {
    if (v %in% rownames(ct)) {
      results[[length(results) + 1]] <- data.table(
        test = "interaction_fta",
        trade = trade,
        variable = v,
        estimate = as.numeric(ct[v, "Estimate"]),
        se = as.numeric(ct[v, "Std. Error"]),
        pvalue = as.numeric(ct[v, "Pr(>|z|)"]),
        n = nrow(dt_fit),
        note = ifelse(v == ECON_VAR, "非 FTA 国家经贸互利合作效应", "经贸互利合作 × FTA 交互效应")
      )
    }
  }
}

# ============================================================================
# 4. 协议子类拆分（若事件库含子标签）
# ============================================================================
if (has_subtype) {
  cat("[3/3] 协议子类拆分...\n")
  # 这里仅做占位：若事件库含 subtype 列，可据此生成子类虚拟变量
  # 当前版本跳过，因为 713 事件库未标准化 subtype
  results[[length(results) + 1]] <- data.table(
    test = "subtype_split",
    trade = NA_character_,
    variable = NA_character_,
    estimate = NA_real_,
    se = NA_real_,
    pvalue = NA_real_,
    n = NA_integer_,
    note = "事件库无标准化 subtype，跳过子类拆分。如需此检验，请在事件库中增加 subtype 列。"
  )
} else {
  cat("[3/3] 事件库无子标签，跳过协议子类拆分。\n")
  results[[length(results) + 1]] <- data.table(
    test = "subtype_split",
    trade = NA_character_,
    variable = NA_character_,
    estimate = NA_real_,
    se = NA_real_,
    pvalue = NA_real_,
    n = NA_integer_,
    note = "事件库无标准化 subtype，跳过子类拆分。"
  )
}

out <- rbindlist(results, use.names = TRUE, fill = TRUE)
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "09b_mechanism_economic_cooperation.csv"))
cat(sprintf("✓ 09b_mechanism_economic_cooperation.csv 已保存 (%d 行)\n", nrow(out)))
print(out[, .(test, trade_label, variable, estimate, se, pvalue, sig, note)])
