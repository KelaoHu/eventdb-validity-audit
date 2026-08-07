# 01_cross_db_same_equation.R

rm(list = ls())
library(fixest)
library(data.table)

ROOT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
DATA_DIR <- file.path(ROOT_DIR, "data")
SCORE_DIR <- normalizePath("C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data", winslash = "/")
OUT_DIR <- "../results"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")

# ---- 读取面板 ----
panel <- fread(file.path(DATA_DIR, "panel_clean.csv"), encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, month := as.Date(month)]
panel[, YearMonth := month]
panel[, Country := as.character(Country)]
panel[, ISO := as.character(ISO)]

# ---- 读取分数（与 01_run_irf.R 相同函数） ----
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

gdelt   <- read_score_long(file.path(SCORE_DIR, "gdelt_scores.csv"), "GDELT")
icews   <- read_score_long(file.path(SCORE_DIR, "icews_scores.csv"), "ICEWS")
phoenix <- read_score_long(file.path(SCORE_DIR, "phoenix_scores.csv"), "Phoenix")
tsinghua <- fread(file.path(SCORE_DIR, "tsinghua_scores.csv"), encoding = "UTF-8")
setnames(tsinghua, sub("^\ufeff", "", names(tsinghua)))
tsinghua[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
setnames(tsinghua, c("Country", "YearMonth", "Score"), c("Country", "YearMonth", "Pol_Agg"))
tsinghua[, db := "Tsinghua"]

scores <- rbindlist(list(gdelt, icews, phoenix, tsinghua), fill = TRUE, use.names = TRUE)

# ---- 合并到面板并按 01_run_irf.R 口径生成冲击 u_Agg ----
panel_db <- merge(panel, scores, by = c("Country", "YearMonth"), all.x = TRUE)
setorder(panel_db, db, ISO, YearMonth)

make_zscore <- function(x) {
  mu <- mean(x, na.rm = TRUE)
  sg <- sd(x, na.rm = TRUE)
  if (is.na(sg) || sg == 0) rep(NA_real_, length(x)) else (x - mu) / sg
}

panel_db[, PolZ_Agg := make_zscore(Pol_Agg), by = .(db, ISO)]
# 清华：单位根过程，一阶差分后 z-score
panel_db[, dPol_Agg := Pol_Agg - shift(Pol_Agg, 1, type = "lag"), by = .(db, ISO)]
panel_db[db == "Tsinghua", PolZ_Agg := make_zscore(dPol_Agg), by = ISO]

extract_ar1_resid <- function(x) {
  if (sum(!is.na(x)) < 12) return(rep(NA_real_, length(x)))
  fit <- tryCatch(arima(x, order = c(1, 0, 0), include.mean = TRUE), error = function(e) NULL)
  if (is.null(fit)) return(rep(NA_real_, length(x)))
  as.vector(residuals(fit))
}

panel_db[, u_Agg := extract_ar1_resid(PolZ_Agg), by = .(db, ISO)]
panel_db[db == "Tsinghua", u_Agg := PolZ_Agg]  # 差分 z-score 直接作冲击

# ---- 整理为宽表：每个国家-月份一行，四库冲击并列 ----
u_wide <- dcast(panel_db[, .(ISO, Country, YearMonth, db, u_Agg)],
                ISO + Country + YearMonth ~ db, value.var = "u_Agg")
base <- merge(panel[, .(ISO, Country, YearMonth, Trade_Total, Trade_Exports, Trade_Imports,
                        ln_GDP_product, ln_ER, FTA_Dummy)],
              u_wide[, .(ISO, YearMonth, GDELT, ICEWS, Phoenix, Tsinghua)],
              by = c("ISO", "YearMonth"), all.x = TRUE)

# 清华覆盖的 11 国（清华 12 国中 Pakistan 不在 25 国面板）
ts_countries <- intersect(unique(tsinghua$Country), unique(panel$Country))
ts_iso <- unique(panel[Country %in% ts_countries, ISO])
cat("清华覆盖国家（面板内", length(ts_iso), "国）:", paste(ts_iso, collapse = ", "), "\n")

# ---- 回归函数 ----
run_spec <- function(dt, trade, shock_vars, spec_label) {
  need <- c(trade, shock_vars, CONTROLS)
  dt_fit <- dt[complete.cases(dt[, ..need])]
  rhs <- paste(c(shock_vars, CONTROLS), collapse = " + ")
  fml <- as.formula(sprintf("%s ~ %s | ISO + YearMonth", trade, rhs))
  fit <- tryCatch(
    fepois(fml, data = dt_fit, cluster = ~ISO + YearMonth, glm.iter = 100),
    error = function(e) { cat("  错误:", conditionMessage(e), "\n"); NULL }
  )
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  res <- rbindlist(lapply(shock_vars, function(v) {
    data.table(
      spec = spec_label,
      trade = trade,
      db = v,
      coef = as.numeric(ct[v, "Estimate"]),
      se = as.numeric(ct[v, "Std. Error"]),
      p = as.numeric(ct[v, "Pr(>|z|)"]),
      n = nrow(dt_fit),
      n_country = uniqueN(dt_fit$ISO),
      sample_start = as.character(min(dt_fit$YearMonth)),
      sample_end = as.character(max(dt_fit$YearMonth))
    )
  }))
  res
}

results <- list()

# ---- 规格 (a)：三库同方程，25 国 ----
cat("[规格a] 三库（GDELT+ICEWS+Phoenix）同方程，25 国全样本\n")
shocks3 <- c("GDELT", "ICEWS", "Phoenix")
for (trade in TRADE_VARS) {
  r <- run_spec(base, trade, shocks3, "A_三库同方程_25国")
  if (!is.null(r)) results[[length(results) + 1]] <- r
}

# ---- 规格 (b)：四库同方程，清华 11 国 ----
cat("[规格b] 四库（+Tsinghua）同方程，清华覆盖 11 国\n")
shocks4 <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
base_ts <- base[ISO %in% ts_iso]
for (trade in TRADE_VARS) {
  r <- run_spec(base_ts, trade, shocks4, "B_四库同方程_11国")
  if (!is.null(r)) results[[length(results) + 1]] <- r
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))]
setcolorder(out, c("spec", "trade", "db", "coef", "se", "p", "sig", "n", "n_country", "sample_start", "sample_end"))
fwrite(out, file.path(OUT_DIR, "cross_db_same_equation.csv"))
cat(sprintf("✓ cross_db_same_equation.csv 已保存（%d 行）\n", nrow(out)))
print(out)
