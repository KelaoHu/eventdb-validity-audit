# 05_run_freq_scan.R

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

# 扫描窗口
K_VALUES <- c(1, 2, 3, 4, 6, 12, 24)

# 生成足够的滞后变量（最多到 23 期）
MAX_K <- max(K_VALUES)
for (h in 7:(MAX_K - 1)) {
  panel_db[, (paste0("u_Agg_L", h)) := shift(u_Agg, n = h, type = "lag"), by = .(db, ISO)]
}

results <- list()

for (db_label in DBS) {
  dt_sub <- panel_db[db == db_label]
  
  for (k in K_VALUES) {
    # 生成 k 期累计冲击变量
    cum_var <- paste0("u_Agg_cum", k)
    # 对 t 时刻，累计 t-k+1 到 t 的冲击
    if (k == 1) {
      dt_sub[, (cum_var) := u_Agg]
    } else {
      lag_vars <- paste0("u_Agg_L", 1:(k-1))
      dt_sub[, (cum_var) := u_Agg + rowSums(.SD, na.rm = TRUE), .SDcols = lag_vars]
    }
    
    trade <- "Trade_Total"
    dt_fit <- dt_sub[!is.na(get(trade)) & !is.na(get(cum_var)) &
                       !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
    if (nrow(dt_fit) < 50) next
    
    formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                           trade, cum_var, paste(CONTROLS, collapse = " + "))
    fit <- tryCatch(
      fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
      error = function(e) NULL
    )
    if (is.null(fit)) next
    
    coefs <- coeftable(fit)
    if (!cum_var %in% rownames(coefs)) next
    
    est <- coefs[cum_var, "Estimate"]
    se <- coefs[cum_var, "Std. Error"]
    pv <- coefs[cum_var, "Pr(>|z|)"]
    
    results[[length(results) + 1]] <- data.table(
      db = db_label,
      label = paste0("k=", k),
      n = nrow(dt_fit),
      cum = est,
      h0 = est,
      h0p = pv,
      k = k
    )
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, db := factor(db, levels = DBS)]
setorder(out, db, k)

fwrite(out, file.path(OUT_DIR, "B_freqscan.csv"))
cat("✓ B_freqscan.csv saved (", nrow(out), "rows)\n")
