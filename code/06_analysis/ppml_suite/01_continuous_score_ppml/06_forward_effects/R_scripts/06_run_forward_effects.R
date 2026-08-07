# 06_run_forward_effects.R

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

# 只用 GDELT aggregate 冲击做领先滞后（与现有 D_forward.csv 一致）
dt_sub <- panel_db[db == "GDELT"]
trade <- "Trade_Total"

# 生成前导变量 h = -3, -2, -1
for (h in 1:3) {
  dt_sub[, (paste0("u_Agg_F", h)) := shift(u_Agg, n = h, type = "lead"), by = ISO]
}

H_VALUES <- -3:6

results <- list()

for (h in H_VALUES) {
  # 构造解释变量名
  if (h < 0) {
    x_var <- paste0("u_Agg_F", abs(h))
  } else if (h == 0) {
    x_var <- "u_Agg"
  } else {
    x_var <- paste0("u_Agg_L", h)
  }
  
  if (!x_var %in% names(dt_sub)) next
  
  dt_fit <- dt_sub[!is.na(get(trade)) & !is.na(get(x_var)) &
                     !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  if (nrow(dt_fit) < 50) next
  
  formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                         trade, x_var, paste(CONTROLS, collapse = " + "))
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) next
  
  coefs <- coeftable(fit)
  if (!x_var %in% rownames(coefs)) next
  
  results[[length(results) + 1]] <- data.table(
    h = h,
    Est = coefs[x_var, "Estimate"],
    SE = coefs[x_var, "Std. Error"],
    pv = coefs[x_var, "Pr(>|z|)"]
  )
}

out <- rbindlist(results, use.names = TRUE)
setorder(out, h)

fwrite(out, file.path(OUT_DIR, "D_forward.csv"))
cat("✓ D_forward.csv saved (", nrow(out), "rows)\n")
