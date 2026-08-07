# 01_run_irf.R

rm(list = ls())

# ---- 包加载 ----
pkgs <- c("fixest", "data.table", "dplyr", "readr", "tidyr", "ggplot2", "stringr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

# ---- 路径 ----
SCRIPT_DIR <- dirname(normalizePath(commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))][1], winslash = "/"))
if (is.na(SCRIPT_DIR) || SCRIPT_DIR == "") SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)           # ../01_基准传导_季度冲击/
PPML_DIR <- dirname(TEST_DIR)             # ../01_连续分数PPML/
ROOT_DIR <- dirname(PPML_DIR)             # 新PPMLHDFE 根目录
DATA_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE/data"
RESULTS_DIR <- file.path(TEST_DIR, "检验结果CSV")  # 同一检验目录下的 检验结果CSV
SCORE_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"
SCORE_DIR <- normalizePath(SCORE_DIR, winslash = "/")

dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- 读取面板 ----
cat("[1/6] 读取面板数据...\n")
panel <- fread(file = file.path(DATA_DIR, "panel_clean.csv"), encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, month := as.Date(month)]
panel[, YearMonth := month]
panel[, Country := as.character(Country)]
panel[, ISO := as.character(ISO)]

# ---- 国家名映射（score 文件用全名，panel 用 ISO + 全名）----
iso_map <- unique(panel[, .(ISO, Country)])

# ---- 读取并整理政治分数 ----
cat("[2/6] 读取并整理政治分数...\n")

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

# 合并所有分数
scores <- rbindlist(list(gdelt, icews, phoenix, tsinghua), fill = TRUE, use.names = TRUE)

# 合并到面板
panel_db <- merge(panel, scores, by = c("Country", "YearMonth"), all.x = TRUE)
setorder(panel_db, db, ISO, YearMonth)

# ---- 生成标准化分数与冲击 ----
cat("[3/6] 生成标准化分数与 AR(1) 冲击...\n")

make_zscore <- function(x) {
  mu <- mean(x, na.rm = TRUE)
  sg <- sd(x, na.rm = TRUE)
  if (is.na(sg) || sg == 0) rep(NA_real_, length(x)) else (x - mu) / sg
}

# 对国家-方向做 z-score
panel_db[, PolZ_Agg := make_zscore(Pol_Agg), by = .(db, ISO)]
panel_db[, PolZ_CHN_Partner := make_zscore(Pol_CHN_Partner), by = .(db, ISO)]
panel_db[, PolZ_Partner_CHN := make_zscore(Pol_Partner_CHN), by = .(db, ISO)]

# Tsinghua 为单位根过程，使用一阶差分后的变化量
panel_db[, dPol_Agg := get("Pol_Agg") - shift(get("Pol_Agg"), 1, type = "lag"), by = .(db, ISO)]
panel_db[db == "Tsinghua", PolZ_Agg := make_zscore(dPol_Agg), by = ISO]
panel_db[db == "Tsinghua", PolZ_CHN_Partner := NA_real_]
panel_db[db == "Tsinghua", PolZ_Partner_CHN := NA_real_]

# AR(1) 残差作为冲击
extract_ar1_resid <- function(x) {
  if (sum(!is.na(x)) < 12) return(rep(NA_real_, length(x)))
  fit <- tryCatch(arima(x, order = c(1, 0, 0), include.mean = TRUE), error = function(e) NULL)
  if (is.null(fit)) return(rep(NA_real_, length(x)))
  as.vector(residuals(fit))
}

panel_db[, u_Agg := extract_ar1_resid(PolZ_Agg), by = .(db, ISO)]
panel_db[, u_CHN_Partner := extract_ar1_resid(PolZ_CHN_Partner), by = .(db, ISO)]
panel_db[, u_Partner_CHN := extract_ar1_resid(PolZ_Partner_CHN), by = .(db, ISO)]

# Tsinghua 差分后 AR(1) 残差即近似为差分本身（差分序列接近白噪声）
panel_db[db == "Tsinghua", u_Agg := PolZ_Agg]  # 对差分 z-score 直接用作冲击

# 生成滞后变量 h = 1:6
for (v in c("u_Agg", "u_CHN_Partner", "u_Partner_CHN")) {
  for (h in 1:6) {
    panel_db[, (paste0(v, "_L", h)) := shift(get(v), n = h, type = "lag"), by = .(db, ISO)]
  }
}

# ---- 计算 AR(1) rho 用于 scaling ----
cat("[4/6] 计算 AR(1) rho（用于 scaling 报告）...\n")
rho_df <- panel_db[, {
  x <- PolZ_Agg[!is.na(PolZ_Agg)]
  if (length(x) > 12) {
    fit <- tryCatch(arima(x, order = c(1, 0, 0)), error = function(e) NULL)
    rho <- if (!is.null(fit)) fit$coef["ar1"] else NA_real_
  } else {
    rho <- NA_real_
  }
  .(rho = rho, n = length(x))
}, by = .(db, ISO)]

# 对 Tsinghua 同时报告差分后的 rho
diff_rho_df <- panel_db[db == "Tsinghua", {
  dx <- dPol_Agg[!is.na(dPol_Agg)]
  if (length(dx) > 12) {
    fit <- tryCatch(arima(dx, order = c(1, 0, 0)), error = function(e) NULL)
    rho <- if (!is.null(fit)) fit$coef["ar1"] else NA_real_
  } else {
    rho <- NA_real_
  }
  .(rho = rho, n = length(dx))
}, by = .(db, ISO)]

# ---- 运行 IRF ----
cat("[5/6] 运行 PPML IRF（h = 0..6）...\n")

DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
SHOCK_MAP <- list(
  "Total" = "u_Agg",
  "Export" = "u_CHN_Partner",
  "Import" = "u_Partner_CHN"
)
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
HORIZONS <- 0:6

run_ppml_irf <- function(dt_sub, trade, shock, h, db_label, spec_label) {
  x_var <- if (h == 0) shock else paste0(shock, "_L", h)
  if (!x_var %in% names(dt_sub)) return(NULL)
  
  dt_fit <- dt_sub[!is.na(get(trade)) & !is.na(get(x_var)) &
                     !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  if (nrow(dt_fit) < 50) return(NULL)
  
  formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth",
                         trade, x_var, paste(CONTROLS, collapse = " + "))
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)
  
  coefs <- coeftable(fit)
  if (!x_var %in% rownames(coefs)) return(NULL)
  
  est <- coefs[x_var, "Estimate"]
  se <- coefs[x_var, "Std. Error"]
  pv <- coefs[x_var, "Pr(>|z|)"]
  
  data.table(
    db = db_label,
    spec = spec_label,
    trade = trade,
    h = h,
    Est = est,
    SE = se,
    pv = pv,
    cum = NA_real_,
    n = nrow(dt_fit)
  )
}

irf_all <- list()

for (db_label in DBS) {
  cat(sprintf("  -> %s\n", db_label))
  dt_sub <- panel_db[db == db_label]
  
  for (spec_name in names(SHOCK_MAP)) {
    shock <- SHOCK_MAP[[spec_name]]
    
    # Tsinghua 只有 Pol_Agg，Export/Import spec 仍用 u_Agg 但对应不同 trade outcome
    if (db_label == "Tsinghua" && spec_name != "Total") shock <- "u_Agg"
    if (!shock %in% names(dt_sub)) next
    
    spec_label <- paste0(switch(db_label,
                                "GDELT" = "GD",
                                "ICEWS" = "IW",
                                "Phoenix" = "PH",
                                "Tsinghua" = "TS"), "-", spec_name)
    
    for (trade in TRADE_VARS) {
      for (h in HORIZONS) {
        res <- run_ppml_irf(dt_sub, trade, shock, h, db_label, spec_label)
        if (!is.null(res)) irf_all[[length(irf_all) + 1]] <- res
      }
    }
  }
}

irf_dt <- rbindlist(irf_all, use.names = TRUE)

# 填充 cum：取 h=0:6 的累计（与历史 cum 列一致）
irf_dt[, cum := sum(Est, na.rm = TRUE), by = .(db, spec, trade)]

# ---- 保存结果 ----
cat("[6/6] 保存结果...\n")
for (db_label in DBS) {
  out_dir <- file.path(RESULTS_DIR, db_label)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  fwrite(irf_dt[db == db_label, .(db, spec, trade, h, Est, SE, pv, cum, n)],
         file.path(out_dir, "irf_all.csv"))
  cat(sprintf("  ✓ %s/irf_all.csv (%d rows)\n", db_label, nrow(irf_dt[db == db_label])))
}

# ---- 保存 scaling 报告 ----
scaling_dir <- file.path(PPML_DIR, "07_信噪比效应量标度律", "检验结果CSV")
dir.create(scaling_dir, recursive = TRUE, showWarnings = FALSE)

scaling_summary <- rho_df[, .(
  rho = mean(rho, na.rm = TRUE),
  n_country = uniqueN(ISO),
  n_obs = sum(n, na.rm = TRUE)
), by = db]

# Tsinghua 使用差分后的 rho
scaling_summary[db == "Tsinghua", rho := diff_rho_df[, mean(rho, na.rm = TRUE)]]

# cum_d3 从 irf 汇总：每个 db 的 Aggregate/Total trade 在 h=3 的累计
cum_d3 <- irf_dt[grepl("-Total$", spec) & trade == "Trade_Total", .(
  cum_d3 = sum(Est[h <= 3], na.rm = TRUE)
), by = db]

scaling_summary <- merge(scaling_summary, cum_d3, by = "db", all.x = TRUE)
scaling_summary[, cum_ar := NA_real_]  # 需要 AR 修正后重新跑才能填
fwrite(scaling_summary[, .(db, rho, cum_ar, cum_d3)],
       file.path(scaling_dir, "C_scaling.csv"))

cat("\n全部 IRF 结果已保存。\n")
