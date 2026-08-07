# 04_run_ar1_residual_ppml.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

panel <- load_panel(ROOT_DIR)
scores <- load_scores(ROOT_DIR)
panel_db <- prepare_panel_db(panel, scores)

HORIZONS <- 0:6
DB_PREFIX <- c("GDELT" = "GD", "ICEWS" = "IW", "Phoenix" = "PH", "Tsinghua" = "TS")

# 定义 spec：(label, shock_var, trade_var)
specs <- list(
  list(label = "AR-Total", shock = "u_Agg", trade = "Trade_Total"),
  list(label = "c-Export", shock = "u_CHN_Partner", trade = "Trade_Exports"),
  list(label = "p-Import", shock = "u_Partner_CHN", trade = "Trade_Imports")
)

results <- list()

for (db_label in DBS) {
  dt_sub <- panel_db[db == db_label]
  prefix <- DB_PREFIX[db_label]
  
  for (sp in specs) {
    shock_base <- sp$shock
    trade <- sp$trade
    suffix <- sp$label
    
    # Tsinghua 只有 aggregate 冲击
    if (db_label == "Tsinghua" && shock_base != "u_Agg") next
    
    shock_vars <- sapply(HORIZONS, function(h) {
      if (h == 0) shock_base else paste0(shock_base, "_L", h)
    })
    
    if (!all(shock_vars %in% names(dt_sub))) next
    
    dt_fit <- dt_sub[!is.na(get(trade))]
    for (v in shock_vars) dt_fit <- dt_fit[!is.na(get(v))]
    dt_fit <- dt_fit[!is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
    if (nrow(dt_fit) < 50) next
    
    formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                           trade, paste(shock_vars, collapse = " + "),
                           paste(CONTROLS, collapse = " + "))
    fit <- tryCatch(
      fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    if (is.null(fit)) next
    
    coefs <- coeftable(fit)
    valid <- shock_vars[shock_vars %in% rownames(coefs)]
    if (length(valid) == 0) next
    
    ests <- coefs[valid, "Estimate"]
    ses <- coefs[valid, "Std. Error"]
    pvs <- coefs[valid, "Pr(>|z|)"]
    
    cum_est <- sum(ests, na.rm = TRUE)
    h0_est <- ests[1]
    
    # 累计效应的标准误：sqrt(sum of all elements in shock-block VCOV)
    vc <- vcov(fit)
    cum_se <- sqrt(sum(vc[valid, valid], na.rm = TRUE))
    
    label <- paste0(prefix, "_", suffix)
    results[[length(results) + 1]] <- data.table(
      db = db_label,
      label = label,
      n = nrow(dt_fit),
      cum = cum_est,
      cum_se = cum_se,
      h0 = h0_est,
      h0p = pvs[1]
    )
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, db := factor(db, levels = DBS)]
setorder(out, db)

fwrite(out, file.path(OUT_DIR, "A_AR1.csv"))
cat("✓ A_AR1.csv saved (", nrow(out), "rows)\n")
