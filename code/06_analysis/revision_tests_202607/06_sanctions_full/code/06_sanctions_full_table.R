# 06_sanctions_full_table.R

rm(list = ls())
library(fixest)
library(data.table)

ROOT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
PPML_DIR <- file.path(ROOT_DIR, "02_事件驱动PPMLHDFE")
OLD_DIR <- file.path(PPML_DIR, "09_事件类型深度稳健性与动态分析", "检验结果CSV")
OUT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/06_制裁三维度完整报告/results"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")

panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据",
                            "event_panel_with_directional_sanctions.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# 17 类控制（剔除被方向化变量替代的两类原始变量），与 09m 一致
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$|_F[0-9]+$", cat_cols)]
cat_cols <- setdiff(cat_cols, c("Cat_科技管制/出口限制", "Cat_经贸制裁/关税壁垒"))

tech_cn <- "Cat_科技管制_对华"
sanc_cn <- "Cat_经贸制裁_对华"
other_dir <- c("Cat_科技管制_对伙伴", "Cat_经贸制裁_对伙伴", "Cat_经贸制裁_多边", "Cat_经贸制裁_模糊")
other_dir <- other_dir[other_dir %in% names(panel_ev)]

target_vars <- c(tech_cn, sanc_cn)

# 既有安慰剂 p 值（09m，1000 次事件时间置换，针对含 Event_Negative 的进口方程）
placebo <- fread(file.path(OLD_DIR, "09m_directional_sanction_placebo_summary.csv"), encoding = "UTF-8")

run_one <- function(dt, trade, spec_label, sample_label, placebo_p_map) {
  dt_fit <- dt[!is.na(get(trade))]
  for (cc in CONTROLS) dt_fit <- dt_fit[!is.na(get(cc))]
  rhs <- c(sprintf("`%s`", target_vars), sprintf("`%s`", other_dir),
           sprintf("`%s`", cat_cols), CONTROLS)
  if (spec_label == "含Event_Negative") rhs <- c(rhs, "Event_Negative")
  fml <- as.formula(sprintf("%s ~ %s | ISO + YearMonth", trade, paste(rhs, collapse = " + ")))
  fit <- tryCatch(fepois(fml, data = dt_fit, cluster = ~ISO, glm.iter = 100),
                  error = function(e) { cat("错误:", conditionMessage(e), "\n"); NULL })
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  ev_neg_dropped <- spec_label == "含Event_Negative" && "Event_Negative" %in% fit$collin.var
  note <- if (ev_neg_dropped)
    "Event_Negative因完全共线被剔除：该样本内含Event_Negative设定不可识别，结果与基准仅17类控制等价" else ""
  rbindlist(lapply(target_vars, function(v) {
    b <- as.numeric(ct[v, "Estimate"]); s <- as.numeric(ct[v, "Std. Error"])
    pv <- as.numeric(ct[v, "Pr(>|z|)"])
    data.table(
      sample = sample_label, spec = spec_label, trade = trade, variable = v,
      coef = b, se = s, p = pv,
      pct_effect = exp(b) - 1,
      placebo_p = placebo_p_map[[v]],
      n = nrow(dt_fit), n_country = uniqueN(dt_fit$ISO),
      note = note
    )
  }))
}

# 安慰剂 p 仅在"全样本 × 含Event_Negative × Trade_Imports"组合适用
placebo_map_full <- setNames(as.list(placebo$placebo_pvalue), placebo$variable)
placebo_map_na <- setNames(list(NA_real_, NA_real_), target_vars)

samples <- list(
  "全样本" = panel_ev,
  "排除疫情期2020.01-2021.06" = panel_ev[YearMonth < as.Date("2020-01-01") | YearMonth > as.Date("2021-06-01")]
)

results <- list()
for (s_label in names(samples)) {
  for (spec_label in c("基准仅17类控制", "含Event_Negative")) {
    for (trade in TRADE_VARS) {
      pmap <- if (s_label == "全样本" && spec_label == "含Event_Negative" && trade == "Trade_Imports")
        placebo_map_full else placebo_map_na
      r <- run_one(samples[[s_label]], trade, spec_label, s_label, pmap)
      if (!is.null(r)) results[[length(results) + 1]] <- r
    }
  }
}

out <- rbindlist(results, use.names = TRUE)
out[, sig := ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))]
setcolorder(out, c("sample", "spec", "trade", "variable", "coef", "se", "p", "sig",
                   "pct_effect", "placebo_p", "n", "n_country", "note"))
fwrite(out, file.path(OUT_DIR, "sanctions_full_table.csv"))
cat(sprintf("✓ sanctions_full_table.csv 已保存（%d 行）\n", nrow(out)))
print(out)
