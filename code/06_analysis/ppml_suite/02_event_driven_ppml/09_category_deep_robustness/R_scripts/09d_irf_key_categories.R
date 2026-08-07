# 09d_irf_key_categories.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]
panel_ev <- panel_ev[order(ISO, YearMonth)]

# 17 类变量（参照组：高层互访）
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$|_F[0-9]+$", cat_cols)]
cat_summary <- panel_ev[, lapply(.SD, sum), .SDcols = cat_cols]
cat_freq <- data.table(category = gsub("^Cat_", "", cat_cols), count = as.numeric(cat_summary[1]))
ref_cat <- cat_freq[which.max(count), category]
model_cols <- setdiff(cat_cols, paste0("Cat_", ref_cat))

# 关键类别与对应贸易变量
KEY_PAIRS <- list(
  list(category = "人文交流合作", trade = "Trade_Exports", trade_label = "出口"),
  list(category = "战略定位负面", trade = "Trade_Imports", trade_label = "进口"),
  list(category = "经贸互利合作", trade = "Trade_Total", trade_label = "总贸易"),
  list(category = "经贸互利合作", trade = "Trade_Exports", trade_label = "出口")
)

HORIZONS <- c(-3, -2, -1, 0, 1, 3, 6, 12)

# 生成领先项（pre-trend）
cat("[2/3] 生成领先/滞后变量...\n")
for (cn in unique(sapply(KEY_PAIRS, "[[", "category"))) {
  v <- paste0("Cat_", cn)
  if (!(v %in% names(panel_ev))) next
  for (h in 1:3) {
    panel_ev[, (paste0(v, "_F", h)) := shift(get(v), n = h, type = "lead"), by = ISO]
  }
}

results <- list()
wald_results <- list()

cat("[3/3] 跑关键类别 IRF...\n")
for (pair in KEY_PAIRS) {
  cn <- pair$category
  trade <- pair$trade
  v <- paste0("Cat_", cn)
  
  if (!(v %in% names(panel_ev))) next
  
  cat(sprintf("  %s -> %s\n", cn, pair$trade_label))
  
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
      category = cn,
      trade = trade,
      trade_label = pair$trade_label,
      horizon = h,
      estimate = est,
      se = se,
      pvalue = p,
      ci_lower = est - 1.96 * se,
      ci_upper = est + 1.96 * se,
      n = nrow(dt_fit)
    )
  }
  
  # 预趋势联合 Wald：h = -3, -2, -1
  lead_vars <- paste0(v, "_F", 1:3)
  lead_vars <- lead_vars[lead_vars %in% names(panel_ev)]
  if (length(lead_vars) >= 2) {
    dt_fit <- panel_ev[!is.na(get(trade))]
    for (lv in lead_vars) dt_fit <- dt_fit[!is.na(get(lv))]
    for (c in CONTROLS) dt_fit <- dt_fit[!is.na(get(c))]
    
    formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                           trade,
                           paste(sprintf("`%s`", lead_vars), collapse = " + "),
                           paste(CONTROLS, collapse = " + "))
    fit <- tryCatch(
      fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    if (!is.null(fit)) {
      w <- tryCatch(wald(fit, lead_vars), error = function(e) NULL)
      if (!is.null(w)) {
        p_wald <- if (is.list(w) && "p" %in% names(w)) as.numeric(w$p) else if (is.numeric(w)) as.numeric(w[1]) else NA_real_
        wald_results[[length(wald_results) + 1]] <- data.table(
          category = cn,
          trade = trade,
          test = "pre_trend_joint",
          pvalue = p_wald,
          note = "H0: h=-3,-2,-1 系数联合为0"
        )
      }
    }
  }
  
  # 事后联合 Wald：h = 0, 1, 3, 6, 12
  post_vars <- c(v, paste0(v, "_L", c(1, 3, 6, 12)))
  post_vars <- post_vars[post_vars %in% names(panel_ev)]
  if (length(post_vars) >= 2) {
    dt_fit <- panel_ev[!is.na(get(trade))]
    for (pv in post_vars) dt_fit <- dt_fit[!is.na(get(pv))]
    for (c in CONTROLS) dt_fit <- dt_fit[!is.na(get(c))]
    
    formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                           trade,
                           paste(sprintf("`%s`", post_vars), collapse = " + "),
                           paste(CONTROLS, collapse = " + "))
    fit <- tryCatch(
      fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    if (!is.null(fit)) {
      w <- tryCatch(wald(fit, post_vars), error = function(e) NULL)
      if (!is.null(w)) {
        p_wald <- if (is.list(w) && "p" %in% names(w)) as.numeric(w$p) else if (is.numeric(w)) as.numeric(w[1]) else NA_real_
        wald_results[[length(wald_results) + 1]] <- data.table(
          category = cn,
          trade = trade,
          test = "post_event_joint",
          pvalue = p_wald,
          note = "H0: h=0,1,3,6,12 系数联合为0"
        )
      }
    }
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]

wald_out <- rbindlist(wald_results, use.names = TRUE, fill = TRUE)

fwrite(out, file.path(OUT_DIR, "09d_irf_key_categories.csv"))
fwrite(wald_out, file.path(OUT_DIR, "09d_irf_key_categories_wald.csv"))
cat(sprintf("✓ 09d_irf_key_categories.csv 已保存 (%d 行)\n", nrow(out)))
cat(sprintf("✓ 09d_irf_key_categories_wald.csv 已保存 (%d 行)\n", nrow(wald_out)))

print(out[, .(category, trade_label, horizon, estimate, se, pvalue, sig)])
print(wald_out)
