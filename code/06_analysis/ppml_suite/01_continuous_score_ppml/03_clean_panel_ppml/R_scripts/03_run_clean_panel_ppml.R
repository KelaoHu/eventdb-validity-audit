# 03_run_clean_panel_ppml.R

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

# 为水平分数生成 1-6 期滞后
for (h in 1:6) {
  panel_db[, (paste0("PolZ_Agg_L", h)) := shift(PolZ_Agg, n = h, type = "lag"), by = .(db, ISO)]
  panel_db[, (paste0("PolZ_CHN_Partner_L", h)) := shift(PolZ_CHN_Partner, n = h, type = "lag"), by = .(db, ISO)]
  panel_db[, (paste0("PolZ_Partner_CHN_L", h)) := shift(PolZ_Partner_CHN, n = h, type = "lag"), by = .(db, ISO)]
  
  # 绝对值滞后
  panel_db[, (paste0("PolZ_Agg_abs_L", h)) := shift(abs(PolZ_Agg), n = h, type = "lag"), by = .(db, ISO)]
  panel_db[, (paste0("PolZ_CHN_Partner_abs_L", h)) := shift(abs(PolZ_CHN_Partner), n = h, type = "lag"), by = .(db, ISO)]
  panel_db[, (paste0("PolZ_Partner_CHN_abs_L", h)) := shift(abs(PolZ_Partner_CHN), n = h, type = "lag"), by = .(db, ISO)]
}
# 当期绝对值
panel_db[, PolZ_Agg_abs := abs(PolZ_Agg)]
panel_db[, PolZ_CHN_Partner_abs := abs(PolZ_CHN_Partner)]
panel_db[, PolZ_Partner_CHN_abs := abs(PolZ_Partner_CHN)]

HORIZONS <- 0:6
DB_PREFIX <- c("GDELT" = "GD", "ICEWS" = "IW", "Phoenix" = "PH", "Tsinghua" = "TS")

# 定义要跑的 (label_suffix, shock_prefix, use_abs)
specs <- list(
  list(suffix = "-", shock = "PolZ_Agg", abs = FALSE),
  list(suffix = "abs-", shock = "PolZ_Agg", abs = TRUE),
  list(suffix = "C2P-", shock = "PolZ_CHN_Partner", abs = FALSE),
  list(suffix = "C2P_abs-", shock = "PolZ_CHN_Partner", abs = TRUE),
  list(suffix = "P2C-", shock = "PolZ_Partner_CHN", abs = FALSE),
  list(suffix = "P2C_abs-", shock = "PolZ_Partner_CHN", abs = TRUE)
)

results <- list()

for (db_label in DBS) {
  dt_sub <- panel_db[db == db_label]
  prefix <- DB_PREFIX[db_label]
  
  for (trade in TRADE_VARS) {
    for (sp in specs) {
      suffix <- sp$suffix
      shock_base <- sp$shock
      use_abs <- sp$abs
      
      # Tsinghua 只有 aggregate 分数
      if (db_label == "Tsinghua" && grepl("CHN_Partner|Partner_CHN", shock_base)) next
      
      # 构造滞后变量名
      shock_vars <- sapply(HORIZONS, function(h) {
        base <- if (use_abs) paste0(shock_base, "_abs") else shock_base
        if (h == 0) base else paste0(base, "_L", h)
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
      h0_se <- ses[1]
      h0_pv <- pvs[1]
      
      label <- paste0(prefix, "_", suffix, gsub("Trade_", "", trade))
      
      results[[length(results) + 1]] <- data.table(
        label = label,
        n = nrow(dt_fit),
        cum = cum_est,
        h0 = h0_est,
        h0p = h0_pv
      )
    }
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, db_prefix := sub("_.*$", "", label)]
prefix_order <- c("GD", "IW", "PH", "TS")
out[, db_prefix := factor(db_prefix, levels = prefix_order)]
setorder(out, db_prefix)
out[, db_prefix := NULL]

fwrite(out, file.path(OUT_DIR, "ppml_final.csv"))
cat("✓ ppml_final.csv saved (", nrow(out), "rows)\n")
