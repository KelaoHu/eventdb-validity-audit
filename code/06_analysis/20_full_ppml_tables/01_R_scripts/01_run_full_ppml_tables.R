# 01_run_full_ppml_tables.R

rm(list = ls())

# ---- 包加载 ----
pkgs <- c("fixest", "data.table", "dplyr", "readr", "tidyr", "stringr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

# ---- 路径 ----
args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)][1]
SCRIPT_DIR <- if (!is.na(file_arg)) {
  fp <- sub("^--file=", "", file_arg)
  dirname(normalizePath(fp, winslash = "/"))
} else ""
if (is.na(SCRIPT_DIR) || SCRIPT_DIR == "") SCRIPT_DIR <- getwd()
MODULE_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(MODULE_DIR, "02_输出表格")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE/data"
SCORE_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"
SCORE_DIR <- normalizePath(SCORE_DIR, winslash = "/")

# ---- 读取面板 ----
cat("[1/7] 读取面板数据...\n")
panel <- fread(file = file.path(DATA_DIR, "panel_clean.csv"), encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, month := as.Date(month)]
panel[, YearMonth := month]
panel[, Country := as.character(Country)]
panel[, ISO := as.character(ISO)]

# ---- 读取并整理政治分数 ----
cat("[2/7] 读取并整理政治分数...\n")

read_score_long <- function(csv, db_name) {
  dt <- fread(file = csv, encoding = "UTF-8")
  setnames(dt, sub("^\ufeff", "", names(dt)))
  dt[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
  dt <- dcast(dt, Partner + YearMonth ~ Index_Type, value.var = "Index_Value")
  setnames(dt, c("Aggregated", "CHN->Partner", "Partner->CHN"),
           c("Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"), skip_absent = TRUE)
  dt[, db := db_name]
  dt[, Country := Partner]
  return(dt[, !"Partner"])
}

gdelt <- read_score_long(file.path(SCORE_DIR, "gdelt_scores.csv"), "GDELT")
icews <- read_score_long(file.path(SCORE_DIR, "icews_scores.csv"), "ICEWS")
phoenix <- read_score_long(file.path(SCORE_DIR, "phoenix_scores.csv"), "Phoenix")

tsinghua <- fread(file = file.path(SCORE_DIR, "tsinghua_scores.csv"), encoding = "UTF-8")
setnames(tsinghua, sub("^\ufeff", "", names(tsinghua)))
tsinghua[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
setnames(tsinghua, c("Country", "YearMonth", "Score"), c("Country", "YearMonth", "Pol_Agg"))
tsinghua[, db := "Tsinghua"]

scores <- rbindlist(list(gdelt, icews, phoenix, tsinghua), fill = TRUE, use.names = TRUE)

panel_db <- merge(panel, scores, by = c("Country", "YearMonth"), all.x = TRUE)
setorder(panel_db, db, ISO, YearMonth)

# ---- 生成标准化分数与 AR(1) 冲击 ----
cat("[3/7] 生成标准化分数与 AR(1) 冲击...\n")

make_zscore <- function(x) {
  mu <- mean(x, na.rm = TRUE)
  sg <- sd(x, na.rm = TRUE)
  if (is.na(sg) || sg == 0) rep(NA_real_, length(x)) else (x - mu) / sg
}

panel_db[, PolZ_Agg := make_zscore(Pol_Agg), by = .(db, ISO)]
panel_db[, PolZ_CHN_Partner := make_zscore(Pol_CHN_Partner), by = .(db, ISO)]
panel_db[, PolZ_Partner_CHN := make_zscore(Pol_Partner_CHN), by = .(db, ISO)]

panel_db[, dPol_Agg := get("Pol_Agg") - shift(get("Pol_Agg"), 1, type = "lag"), by = .(db, ISO)]
panel_db[db == "Tsinghua", PolZ_Agg := make_zscore(dPol_Agg), by = ISO]
panel_db[db == "Tsinghua", PolZ_CHN_Partner := NA_real_]
panel_db[db == "Tsinghua", PolZ_Partner_CHN := NA_real_]

extract_ar1_resid <- function(x) {
  if (sum(!is.na(x)) < 12) return(rep(NA_real_, length(x)))
  fit <- tryCatch(arima(x, order = c(1, 0, 0), include.mean = TRUE), error = function(e) NULL)
  if (is.null(fit)) return(rep(NA_real_, length(x)))
  as.vector(residuals(fit))
}

panel_db[, u_Agg := extract_ar1_resid(PolZ_Agg), by = .(db, ISO)]
panel_db[, u_CHN_Partner := extract_ar1_resid(PolZ_CHN_Partner), by = .(db, ISO)]
panel_db[, u_Partner_CHN := extract_ar1_resid(PolZ_Partner_CHN), by = .(db, ISO)]
panel_db[db == "Tsinghua", u_Agg := PolZ_Agg]

for (v in c("u_Agg", "u_CHN_Partner", "u_Partner_CHN")) {
  for (h in 1:6) {
    panel_db[, (paste0(v, "_L", h)) := shift(get(v), n = h, type = "lag"), by = .(db, ISO)]
  }
}

DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
SHOCK_MAP <- list("Total" = "u_Agg", "Export" = "u_CHN_Partner", "Import" = "u_Partner_CHN")
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
HORIZONS <- 0:6

# ---- 辅助函数 ----
run_ppml <- function(dt_fit, trade, x_var, fe = "ISO + YearMonth", cluster = "~ISO") {
  if (!x_var %in% names(dt_fit)) return(NULL)
  formula_str <- sprintf("%s ~ %s + %s | %s", trade, x_var, paste(CONTROLS, collapse = " + "), fe)
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = as.formula(cluster), glm.iter = 100),
    error = function(e) NULL
  )
  return(fit)
}

extract_full_coeftable <- function(fit) {
  if (is.null(fit)) return(NULL)
  ct <- as.data.table(coeftable(fit), keep.rownames = "variable")
  setnames(ct, c("Estimate", "Std. Error", "z value", "Pr(>|z|)"), c("estimate", "se", "z", "pval"))
  ct[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
  ct[, display := sprintf("%.3f%s\n(%.3f)", estimate, sig, se)]
  return(ct)
}

# ============================================================================
# 表 S4-1：完整基线模型系数表（GDELT, Trade_Total, h=0）
# ============================================================================
cat("[4/7] 生成表 S4-1 完整基线系数...\n")

dt_gdelt <- panel_db[db == "GDELT"]
dt_fit_base <- dt_gdelt[!is.na(Trade_Total) & !is.na(u_Agg) &
                          !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
fit_base <- run_ppml(dt_fit_base, "Trade_Total", "u_Agg")

ct_base <- extract_full_coeftable(fit_base)
ct_base[, variable_label := fcase(
  variable == "u_Agg", "Political shock (AR(1) residual)",
  variable == "ln_GDP_product", "ln(GDP_i \\times GDP_j)",
  variable == "ln_ER", "ln(exchange rate)",
  variable == "FTA_Dummy", "FTA dummy",
  default = variable
)]
ct_base <- ct_base[, .(variable_label, estimate, se, z, pval, sig)]

fit_stats <- data.table(
  metric = c("Observations", "Pseudo R-squared", "Log-likelihood", "Deviance", "Country FE", "YearMonth FE", "Clustering"),
  value = c(
    as.character(fit_base$nobs),
    sprintf("%.4f", fit_base$pseudo_r2),
    sprintf("%.2f", fit_base$loglik),
    sprintf("%.2f", fit_base$deviance),
    "Yes", "Yes", "Country"
  )
)

fwrite(ct_base, file.path(OUT_DIR, "S4_01_baseline_full_coeftable.csv"))
fwrite(fit_stats, file.path(OUT_DIR, "S4_01_baseline_fitstats.csv"))

# ============================================================================
# 表 S4-2：LP 估计汇总（β, SE, p, N, pseudo R²）
# ============================================================================
cat("[5/7] 生成表 S4-2 LP 估计汇总...\n")

lp_rows <- list()
for (db_label in DBS) {
  dt_sub <- panel_db[db == db_label]
  for (spec_name in names(SHOCK_MAP)) {
    shock <- SHOCK_MAP[[spec_name]]
    if (db_label == "Tsinghua" && spec_name != "Total") shock <- "u_Agg"
    if (!shock %in% names(dt_sub)) next
    spec_label <- paste0(switch(db_label,
                                "GDELT" = "GD",
                                "ICEWS" = "IW",
                                "Phoenix" = "PH",
                                "Tsinghua" = "TS"), "-", spec_name)
    for (trade in TRADE_VARS) {
      for (h in HORIZONS) {
        x_var <- if (h == 0) shock else paste0(shock, "_L", h)
        dt_fit <- dt_sub[!is.na(get(trade)) & !is.na(get(x_var)) &
                           !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
        if (nrow(dt_fit) < 50) next
        fit <- run_ppml(dt_fit, trade, x_var)
        if (is.null(fit)) next
        ct <- coeftable(fit)
        if (!x_var %in% rownames(ct)) next
        lp_rows[[length(lp_rows) + 1]] <- data.table(
          db = db_label, spec = spec_label, trade = trade, h = h,
          estimate = ct[x_var, "Estimate"],
          se = ct[x_var, "Std. Error"],
          pval = ct[x_var, "Pr(>|z|)"],
          nobs = fit$nobs,
          pseudo_r2 = fit$pseudo_r2
        )
      }
    }
  }
}
lp_dt <- rbindlist(lp_rows, use.names = TRUE)
lp_dt[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
lp_dt[, cell := sprintf("%.3f%s\n(%.3f)", estimate, sig, se)]

fwrite(lp_dt, file.path(OUT_DIR, "S4_02_lp_estimates.csv"))

# 同时输出一个便于人工阅读的 wide 版
lp_wide <- dcast(lp_dt, db + spec + trade ~ h, value.var = "cell")
fwrite(lp_wide, file.path(OUT_DIR, "S4_02_lp_estimates_wide.csv"))

# ============================================================================
# 表 S4-3：稳健性检验
# ============================================================================
cat("[6/7] 生成表 S4-3 稳健性检验...\n")

rob_rows <- list()

# 辅助函数：提取冲击变量系数
extract_shock_coef <- function(fit, x_var) {
  if (is.null(fit)) return(data.table(estimate = NA_real_, se = NA_real_, pval = NA_real_, nobs = NA_integer_, pseudo_r2 = NA_real_))
  ct <- coeftable(fit)
  if (!x_var %in% rownames(ct)) return(data.table(estimate = NA_real_, se = NA_real_, pval = NA_real_, nobs = fit$nobs, pseudo_r2 = fit$pseudo_r2))
  data.table(
    estimate = ct[x_var, "Estimate"],
    se = ct[x_var, "Std. Error"],
    pval = ct[x_var, "Pr(>|z|)"],
    nobs = fit$nobs,
    pseudo_r2 = fit$pseudo_r2
  )
}

# 1. 基准（GDELT Trade_Total h=0,1,3,6）
for (h in c(0, 1, 3, 6)) {
  x_var <- if (h == 0) "u_Agg" else paste0("u_Agg", "_L", h)
  dt_fit <- dt_gdelt[!is.na(Trade_Total) & !is.na(get(x_var)) &
                       !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  fit <- run_ppml(dt_fit, "Trade_Total", x_var)
  res <- extract_shock_coef(fit, x_var)
  res[, test := sprintf("基准 (h=%d)", h)]
  rob_rows[[length(rob_rows) + 1]] <- res
}

# 2. AR1 残差（即基准，但单独标注）
for (h in c(0, 3)) {
  x_var <- if (h == 0) "u_Agg" else paste0("u_Agg", "_L", h)
  dt_fit <- dt_gdelt[!is.na(Trade_Total) & !is.na(get(x_var)) &
                       !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  fit <- run_ppml(dt_fit, "Trade_Total", x_var)
  res <- extract_shock_coef(fit, x_var)
  res[, test := sprintf("AR(1) 残差 (h=%d)", h)]
  rob_rows[[length(rob_rows) + 1]] <- res
}

# 3. 频率扫描（k = 1,2,3,4,6,12 个月求和）
for (k in c(1, 2, 3, 4, 6, 12)) {
  varname <- paste0("u_Agg_sum_k", k)
  panel_db[, (varname) := frollsum(u_Agg, n = k, align = "right", na.rm = TRUE), by = .(db, ISO)]
  dt_fit <- panel_db[db == "GDELT" & !is.na(Trade_Total) & !is.na(get(varname)) &
                       !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  fit <- run_ppml(dt_fit, "Trade_Total", varname)
  res <- extract_shock_coef(fit, varname)
  res[, test := sprintf("频率扫描 k=%d", k)]
  rob_rows[[length(rob_rows) + 1]] <- res
}

# 4. 前向效应（h = -3..3）
for (h in c(-3:-1)) {
  varname <- paste0("u_Agg_F", abs(h))
  panel_db[, (varname) := shift(u_Agg, n = abs(h), type = "lead"), by = .(db, ISO)]
  dt_fit <- panel_db[db == "GDELT" & !is.na(Trade_Total) & !is.na(get(varname)) &
                       !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  fit <- run_ppml(dt_fit, "Trade_Total", varname)
  res <- extract_shock_coef(fit, varname)
  res[, test := sprintf("前向 h=%d", h)]
  rob_rows[[length(rob_rows) + 1]] <- res
}

# 5. 样本排除
exclusion_specs <- list(
  "排除美国" = dt_gdelt[ISO != "US"],
  "排除疫情期" = dt_gdelt[YearMonth < as.Date("2020-01-01") | YearMonth > as.Date("2022-12-01")],
  "排除伊朗" = dt_gdelt[ISO != "IRN"],
  "截断 2019-03" = dt_gdelt[YearMonth <= as.Date("2019-03-01")],
  "剔除贸易 1% 极端值" = dt_gdelt[Trade_Total >= quantile(Trade_Total, 0.01, na.rm = TRUE) &
                                    Trade_Total <= quantile(Trade_Total, 0.99, na.rm = TRUE)]
)
for (test_name in names(exclusion_specs)) {
  dt_sub <- exclusion_specs[[test_name]]
  dt_fit <- dt_sub[!is.na(Trade_Total) & !is.na(u_Agg) &
                     !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  fit <- run_ppml(dt_fit, "Trade_Total", "u_Agg")
  res <- extract_shock_coef(fit, "u_Agg")
  res[, test := paste0(test_name, " (h=0)")]
  rob_rows[[length(rob_rows) + 1]] <- res
}

rob_dt <- rbindlist(rob_rows, use.names = TRUE, fill = TRUE)
rob_dt[, sig := ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))]
rob_dt[, cell := sprintf("%.3f%s\n(%.3f)", estimate, sig, se)]
fwrite(rob_dt, file.path(OUT_DIR, "S4_03_robustness_checks.csv"))

# ============================================================================
# 表 S4-4：安慰剂检验
# ============================================================================
cat("[7/7] 生成表 S4-4 安慰剂检验...\n")

set.seed(20250729)
N_PERM <- 100

dt_base <- dt_gdelt[!is.na(Trade_Total) & !is.na(u_Agg) &
                      !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
fit_real <- run_ppml(dt_base, "Trade_Total", "u_Agg")
real_coef <- coeftable(fit_real)["u_Agg", "Estimate"]
real_pval <- coeftable(fit_real)["u_Agg", "Pr(>|z|)"]

placebo_rows <- list()

# 1. 国家标签置换
perm_country <- numeric(N_PERM)
for (b in 1:N_PERM) {
  dt_perm <- copy(dt_base)
  dt_perm[, u_Agg_perm := sample(u_Agg, .N, replace = FALSE), by = ISO]
  fit_p <- run_ppml(dt_perm, "Trade_Total", "u_Agg_perm")
  ct_p <- coeftable(fit_p)
  perm_country[b] <- if ("u_Agg_perm" %in% rownames(ct_p)) ct_p["u_Agg_perm", "Estimate"] else NA_real_
}
perm_country <- perm_country[!is.na(perm_country)]
placebo_rows[[1]] <- data.table(
  placebo_type = "国家标签置换",
  real_estimate = real_coef,
  placebo_mean = mean(perm_country),
  placebo_sd = sd(perm_country),
  placebo_pvalue = mean(abs(perm_country) >= abs(real_coef)),
  n_perm = length(perm_country)
)

# 2. 随机正态冲击
perm_normal <- numeric(N_PERM)
for (b in 1:N_PERM) {
  dt_perm <- copy(dt_base)
  dt_perm[, u_Agg_perm := rnorm(.N)]
  fit_p <- run_ppml(dt_perm, "Trade_Total", "u_Agg_perm")
  ct_p <- coeftable(fit_p)
  perm_normal[b] <- if ("u_Agg_perm" %in% rownames(ct_p)) ct_p["u_Agg_perm", "Estimate"] else NA_real_
}
perm_normal <- perm_normal[!is.na(perm_normal)]
placebo_rows[[2]] <- data.table(
  placebo_type = "随机正态冲击",
  real_estimate = real_coef,
  placebo_mean = mean(perm_normal),
  placebo_sd = sd(perm_normal),
  placebo_pvalue = mean(abs(perm_normal) >= abs(real_coef)),
  n_perm = length(perm_normal)
)

# 3. 时间块平移（随机平移 6-24 个月）
perm_time <- numeric(N_PERM)
for (b in 1:N_PERM) {
  shift_k <- sample(6:24, 1)
  dt_perm <- copy(dt_base)
  dt_perm[, u_Agg_perm := shift(u_Agg, n = shift_k, type = "lag"), by = ISO]
  dt_perm <- dt_perm[!is.na(u_Agg_perm)]
  fit_p <- run_ppml(dt_perm, "Trade_Total", "u_Agg_perm")
  ct_p <- coeftable(fit_p)
  perm_time[b] <- if ("u_Agg_perm" %in% rownames(ct_p)) ct_p["u_Agg_perm", "Estimate"] else NA_real_
}
perm_time <- perm_time[!is.na(perm_time)]
placebo_rows[[3]] <- data.table(
  placebo_type = "时间块平移",
  real_estimate = real_coef,
  placebo_mean = mean(perm_time),
  placebo_sd = sd(perm_time),
  placebo_pvalue = mean(abs(perm_time) >= abs(real_coef)),
  n_perm = length(perm_time)
)

placebo_dt <- rbindlist(placebo_rows, use.names = TRUE)
fwrite(placebo_dt, file.path(OUT_DIR, "S4_04_placebo_tests.csv"))

cat(sprintf("\n✓ S4_01_baseline_full_coeftable.csv (%d 行)\n", nrow(ct_base)))
cat(sprintf("✓ S4_02_lp_estimates.csv (%d 行)\n", nrow(lp_dt)))
cat(sprintf("✓ S4_03_robustness_checks.csv (%d 行)\n", nrow(rob_dt)))
cat(sprintf("✓ S4_04_placebo_tests.csv (%d 行)\n", nrow(placebo_dt)))
