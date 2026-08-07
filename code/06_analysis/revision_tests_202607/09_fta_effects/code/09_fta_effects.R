# 09_fta_effects.R

rm(list = ls())
library(fixest)
library(data.table)

ROOT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
OUT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/09_FTA基准效应/results"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
CONTROLS <- c("ln_GDP_product", "ln_ER")

panel <- fread(file.path(ROOT_DIR, "data", "panel_clean.csv"), encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, month := as.Date(month)]
panel[, YearMonth := month]
panel[, ISO := as.character(ISO)]

# ---- (1) 基准 FTA_Dummy 回归 ----
cat("[1/2] 基准 FTA_Dummy 回归...\n")
res_base <- list()
for (trade in TRADE_VARS) {
  dt_fit <- panel[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  fml <- as.formula(sprintf("%s ~ FTA_Dummy + %s | ISO + YearMonth", trade, paste(CONTROLS, collapse = " + ")))
  fit <- fepois(fml, data = dt_fit, cluster = ~ISO + YearMonth, glm.iter = 100)
  ct <- coeftable(fit)
  b <- as.numeric(ct["FTA_Dummy", "Estimate"]); s <- as.numeric(ct["FTA_Dummy", "Std. Error"])
  res_base[[length(res_base) + 1]] <- data.table(
    trade = trade, variable = "FTA_Dummy",
    coef = b, se = s, p = as.numeric(ct["FTA_Dummy", "Pr(>|z|)"]),
    pct_effect = exp(b) - 1,
    n = nrow(dt_fit), n_country = uniqueN(dt_fit$ISO)
  )
}
out_base <- rbindlist(res_base)
out_base[, sig := ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))]
fwrite(out_base, file.path(OUT_DIR, "fta_effects.csv"))
cat("✓ fta_effects.csv\n"); print(out_base)

# ---- (2) 事件研究 ----
cat("[2/2] 事件研究（k = -6..+12，基期 -7）...\n")
setorder(panel, ISO, YearMonth)
panel[, fta_prev := shift(FTA_Dummy, 1, type = "lag"), by = ISO]
activation <- panel[fta_prev == 0 & FTA_Dummy == 1, .(ISO, act_date = YearMonth)]
cat("样本内 FTA 生效事件：\n"); print(activation)

K_MIN <- -6L; K_MAX <- 12L; K_BASE <- -7L

# 相对月份（按月度差）
month_diff <- function(d1, d2) {
  (as.integer(format(d1, "%Y")) - as.integer(format(d2, "%Y"))) * 12L +
    (as.integer(format(d1, "%m")) - as.integer(format(d2, "%m")))
}

es_panel <- copy(panel)
es_panel[, rel := NA_integer_]
for (i in seq_len(nrow(activation))) {
  iso_i <- activation$ISO[i]; ad <- activation$act_date[i]
  es_panel[ISO == iso_i, rel := month_diff(YearMonth, ad)]
}
es_panel[, rel_capped := rel]  # 不封顶，窗口外全部 0

# 生成事件虚拟变量 D_k（k=-6..12，不含 -7）
k_seq <- setdiff(K_MIN:K_MAX, K_BASE)
for (k in k_seq) {
  nm <- paste0("D_", ifelse(k < 0, paste0("m", -k), paste0("p", k)))
  es_panel[, (nm) := as.integer(!is.na(rel_capped) & rel_capped == k)]
}
d_vars <- paste0("D_", ifelse(k_seq < 0, paste0("m", -k_seq), paste0("p", k_seq)))

# MY 无生效前观测：从事件研究样本剔除
es_fit_panel <- es_panel[ISO != "MY"]

res_es <- list()
for (trade in TRADE_VARS) {
  dt_fit <- es_fit_panel[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER)]
  fml <- as.formula(sprintf("%s ~ %s + %s | ISO + YearMonth",
                            trade, paste(d_vars, collapse = " + "), paste(CONTROLS, collapse = " + ")))
  fit <- fepois(fml, data = dt_fit, cluster = ~ISO + YearMonth, glm.iter = 100)
  ct <- coeftable(fit)
  for (j in seq_along(k_seq)) {
    v <- d_vars[j]
    if (!v %in% rownames(ct)) next
    res_es[[length(res_es) + 1]] <- data.table(
      trade = trade, k = k_seq[j],
      coef = as.numeric(ct[v, "Estimate"]), se = as.numeric(ct[v, "Std. Error"]),
      p = as.numeric(ct[v, "Pr(>|z|)"]),
      ci_lo = as.numeric(ct[v, "Estimate"]) - 1.96 * as.numeric(ct[v, "Std. Error"]),
      ci_hi = as.numeric(ct[v, "Estimate"]) + 1.96 * as.numeric(ct[v, "Std. Error"]),
      n = nrow(dt_fit)
    )
  }
}
out_es <- rbindlist(res_es)
# 基期 k=-7 补 0
base_rows <- data.table(trade = TRADE_VARS, k = K_BASE, coef = 0, se = 0, p = NA_real_,
                        ci_lo = 0, ci_hi = 0, n = NA_integer_)
out_es <- rbind(out_es, base_rows, fill = TRUE)
setorder(out_es, trade, k)
out_es[, sig := ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))]
fwrite(out_es, file.path(OUT_DIR, "fta_event_study.csv"))
cat("✓ fta_event_study.csv\n"); print(out_es[trade == "Trade_Total"])
