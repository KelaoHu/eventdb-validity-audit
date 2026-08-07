# 08c_visit_effects_excl_covid.R

rm(list = ls())
library(fixest); library(data.table)

PPML_ROOT <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
OUT_DIR   <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/08_连续分数补充检验包/08c_访问效应排除疫情期/results"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

CONTROLS   <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
VISIT_VARS <- c("V_RemoteTalk", "V_China_Outbound", "V_Partner_Inbound")
COVID_START <- as.Date("2020-01-01"); COVID_END <- as.Date("2021-06-01")

panel_ev <- fread(file.path(PPML_ROOT, "02_事件驱动PPMLHDFE/00_事件面板构建/中间数据/event_panel_ready.csv"),
                  encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

n_full <- nrow(panel_ev)
panel_ex <- panel_ev[YearMonth < COVID_START | YearMonth > COVID_END]
cat("剔除疫情期 2020.01-2021.06: ", n_full, " -> ", nrow(panel_ex), " 行\n", sep = "")

run_visits <- function(dt, trade, sample_label) {
  dt_fit <- dt[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  fml <- as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth",
                            trade, paste(VISIT_VARS, collapse = " + "),
                            paste(CONTROLS, collapse = " + ")))
  fit <- tryCatch(fepois(fml, data = dt_fit, cluster = ~ISO, glm.iter = 100),
                  error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  rbindlist(lapply(intersect(VISIT_VARS, rownames(ct)), function(v) data.table(
    sample = sample_label, trade = trade, variable = v,
    estimate = ct[v, "Estimate"], se = ct[v, "Std. Error"],
    z = ct[v, "z value"], pvalue = ct[v, "Pr(>|z|)"], n_obs = nrow(dt_fit)
  )))
}

res <- list()
for (trade in TRADE_VARS) {
  res[[length(res) + 1]] <- run_visits(panel_ev, trade, "full_sample")
  res[[length(res) + 1]] <- run_visits(panel_ex, trade, "excl_covid_2020.01_2021.06")
}
out <- rbindlist(res)
out[, sig := fcase(pvalue < 0.01, "***", pvalue < 0.05, "**", pvalue < 0.10, "*", default = "")]
out[, pct_effect := (exp(estimate) - 1) * 100]

fwrite(out, file.path(OUT_DIR, "visit_effects_excl_covid.csv"))
cat("\n✓ visit_effects_excl_covid.csv 已保存 (", nrow(out), " 行)\n", sep = "")
print(out)
