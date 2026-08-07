# 08a_irf_exclude_usa.R

rm(list = ls())
library(fixest); library(data.table)

PPML_ROOT <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
SCORE_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT_DIR   <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/08_连续分数补充检验包/08a_排除美国/results"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- 读取面板（与 01_run_irf.R 相同） ----
panel <- fread(file.path(PPML_ROOT, "data/panel_clean.csv"), encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, YearMonth := as.Date(month)]
panel[, Country := as.character(Country)]
panel[, ISO := as.character(ISO)]

# ---- 读取 GDELT 分数并转宽表（与 01_run_irf.R 相同） ----
gd <- fread(file.path(SCORE_DIR, "gdelt_scores.csv"), encoding = "UTF-8")
setnames(gd, sub("^\ufeff", "", names(gd)))
gd[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
gd <- dcast(gd, Partner + YearMonth ~ Index_Type, value.var = "Index_Value")
setnames(gd, c("Aggregated", "CHN->Partner", "Partner->CHN"),
         c("Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"), skip_absent = TRUE)
gd[, Country := Partner][, Partner := NULL]

panel_db <- merge(panel, gd, by = c("Country", "YearMonth"), all.x = TRUE)
setorder(panel_db, ISO, YearMonth)

# ---- z-score + AR(1) 残差冲击（与 01_run_irf.R 相同；逐国计算，与是否含美国无关） ----
make_zscore <- function(x) {
  mu <- mean(x, na.rm = TRUE); sg <- sd(x, na.rm = TRUE)
  if (is.na(sg) || sg == 0) rep(NA_real_, length(x)) else (x - mu) / sg
}
panel_db[, PolZ_Agg := make_zscore(Pol_Agg), by = ISO]
panel_db[, PolZ_CHN_Partner := make_zscore(Pol_CHN_Partner), by = ISO]
panel_db[, PolZ_Partner_CHN := make_zscore(Pol_Partner_CHN), by = ISO]

extract_ar1_resid <- function(x) {
  if (sum(!is.na(x)) < 12) return(rep(NA_real_, length(x)))
  fit <- tryCatch(arima(x, order = c(1, 0, 0), include.mean = TRUE), error = function(e) NULL)
  if (is.null(fit)) return(rep(NA_real_, length(x)))
  as.vector(residuals(fit))
}
panel_db[, u_Agg := extract_ar1_resid(PolZ_Agg), by = ISO]
panel_db[, u_CHN_Partner := extract_ar1_resid(PolZ_CHN_Partner), by = ISO]
panel_db[, u_Partner_CHN := extract_ar1_resid(PolZ_Partner_CHN), by = ISO]

for (v in c("u_Agg", "u_CHN_Partner", "u_Partner_CHN")) {
  for (h in 1:6) {
    panel_db[, (paste0(v, "_L", h)) := shift(get(v), n = h, type = "lag"), by = ISO]
  }
}

# ---- 排除美国 ----
dt_sub <- panel_db[ISO != "US"]
cat("样本: 国家数 =", uniqueN(dt_sub$ISO), ", 观测 =", nrow(dt_sub), "\n")

# ---- LP-IRF ----
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
SHOCK_MAP  <- list(Total = "u_Agg", Export = "u_CHN_Partner", Import = "u_Partner_CHN")
CONTROLS   <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")

run_ppml_irf <- function(dt_sub, trade, shock, h, spec_label) {
  x_var <- if (h == 0) shock else paste0(shock, "_L", h)
  dt_fit <- dt_sub[!is.na(get(trade)) & !is.na(get(x_var)) &
                     !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  if (nrow(dt_fit) < 50) return(NULL)
  fml <- as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth",
                            trade, x_var, paste(CONTROLS, collapse = " + ")))
  fit <- tryCatch(fepois(fml, data = dt_fit, cluster = ~ISO, glm.iter = 100),
                  error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  if (!x_var %in% rownames(ct)) return(NULL)
  data.table(db = "GDELT", spec = spec_label, trade = trade, h = h,
             Est = ct[x_var, "Estimate"], SE = ct[x_var, "Std. Error"],
             pv = ct[x_var, "Pr(>|z|)"], n = nrow(dt_fit))
}

irf_all <- list()
for (spec_name in names(SHOCK_MAP)) {
  for (trade in TRADE_VARS) {
    for (h in 0:6) {
      r <- run_ppml_irf(dt_sub, trade, SHOCK_MAP[[spec_name]], h,
                        paste0("GD-", spec_name, "_exclUSA"))
      if (!is.null(r)) irf_all[[length(irf_all) + 1]] <- r
    }
  }
}
irf_dt <- rbindlist(irf_all)
irf_dt[, cum := sum(Est, na.rm = TRUE), by = .(spec, trade)]

fwrite(irf_dt[, .(db, spec, trade, h, Est, SE, pv, cum, n)],
       file.path(OUT_DIR, "irf_exclude_usa.csv"))
cat("\n✓ irf_exclude_usa.csv 已保存 (", nrow(irf_dt), " 行)\n", sep = "")
cat("\n[关键结果] GD-Total spec（总贸易 h=0 对照初稿 β=0.0091, p=0.042）:\n")
print(irf_dt[spec == "GD-Total_exclUSA"])
