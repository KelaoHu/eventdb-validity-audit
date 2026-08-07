# 09c_robustness_economic_cooperation.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取事件面板...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]
panel_ev <- panel_ev[order(ISO, YearMonth)]

# 生成汇率波动代理变量：ln_ER 的绝对一阶差分
panel_ev[, d_ln_ER := get("ln_ER") - shift(get("ln_ER"), type = "lag"), by = ISO]
panel_ev[, abs_d_ln_ER := abs(d_ln_ER)]

# 17 类变量（参照组：高层互访）
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$|_F[0-9]+$", cat_cols)]
cat_summary <- panel_ev[, lapply(.SD, sum), .SDcols = cat_cols]
cat_freq <- data.table(category = gsub("^Cat_", "", cat_cols), count = as.numeric(cat_summary[1]))
ref_cat <- cat_freq[which.max(count), category]
model_cols <- setdiff(cat_cols, paste0("Cat_", ref_cat))
ECON_VAR <- "Cat_经贸互利合作"

results <- list()

# ============================================================================
# 1. 稳健性设定
# ============================================================================
cat("[2/3] 稳健性设定...\n")

run_spec <- function(dt, trade, extra_terms = NULL, cluster = "~ISO", 
                     estimator = "ppml", label = "基准") {
  dt_fit <- dt[!is.na(get(trade))]
  for (c in CONTROLS) dt_fit <- dt_fit[!is.na(get(c))]
  if (!is.null(extra_terms)) {
    for (c in extra_terms) dt_fit <- dt_fit[!is.na(get(c))]
  }
  
  other_cats <- setdiff(model_cols, ECON_VAR)
  rhs_base <- c(sprintf("`%s`", other_cats), sprintf("`%s`", ECON_VAR), CONTROLS)
  if (!is.null(extra_terms)) rhs_base <- c(rhs_base, extra_terms)
  
  formula_str <- sprintf("%s ~ %s | ISO + YearMonth", trade, paste(rhs_base, collapse = " + "))
  
  if (estimator == "ppml") {
    fit <- tryCatch(
      fepois(as.formula(formula_str), data = dt_fit, cluster = as.formula(cluster), glm.iter = 100),
      error = function(e) NULL
    )
  } else if (estimator == "ols_log") {
    dt_fit[, log_trade := log(get(trade) + 1)]
    fit <- tryCatch(
      feols(as.formula(paste("log_trade ~", paste(rhs_base, collapse = " + "), "| ISO + YearMonth")),
            data = dt_fit, cluster = as.formula(cluster)),
      error = function(e) NULL
    )
  } else {
    fit <- NULL
  }
  
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  v <- ECON_VAR
  if (!(v %in% rownames(ct))) return(NULL)
  
  pcol <- if ("Pr(>|z|)" %in% colnames(ct)) "Pr(>|z|)" else "Pr(>|t|)"
  
  data.table(
    test = label,
    trade = trade,
    estimate = as.numeric(ct[v, "Estimate"]),
    se = as.numeric(ct[v, "Std. Error"]),
    pvalue = as.numeric(ct[v, pcol]),
    n = nrow(dt_fit),
    note = paste0(estimator, ", cluster=", cluster)
  )
}

specs <- list(
  list(dt = panel_ev, extra = NULL, cluster = "~ISO", est = "ppml", label = "基准 PPML"),
  list(dt = panel_ev[ISO != "US"], extra = NULL, cluster = "~ISO", est = "ppml", label = "排除美国"),
  list(dt = panel_ev[ISO != "IR"], extra = NULL, cluster = "~ISO", est = "ppml", label = "排除伊朗"),
  list(dt = panel_ev[YearMonth < as.Date("2020-01-01") | YearMonth > as.Date("2022-12-01")], 
       extra = NULL, cluster = "~ISO", est = "ppml", label = "排除疫情期"),
  list(dt = panel_ev, extra = NULL, cluster = "~ISO + YearMonth", est = "ppml", label = "双向聚类"),
  list(dt = panel_ev, extra = "abs_d_ln_ER", cluster = "~ISO", est = "ppml", label = "加入汇率波动"),
  list(dt = panel_ev, extra = NULL, cluster = "~ISO", est = "ols_log", label = "OLS log(1+Trade)")
)

for (trade in TRADE_VARS) {
  for (sp in specs) {
    res <- run_spec(sp$dt, trade, extra_terms = sp$extra, cluster = sp$cluster,
                    estimator = sp$est, label = sp$label)
    if (!is.null(res)) results[[length(results) + 1]] <- res
  }
}

# ============================================================================
# 2. 逐事件观测剔除（Leave-one-event-observation-out）
# ============================================================================
cat("  逐事件观测剔除...\n")

for (trade in TRADE_VARS) {
  dt_base <- panel_ev[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  event_rows <- which(dt_base[[ECON_VAR]] == 1)
  n_events <- length(event_rows)
  
  if (n_events == 0) next
  
  if (n_events > 30) {
    set.seed(2025)
    event_rows <- sort(sample(event_rows, 30))
  }
  
  loo_est <- numeric(length(event_rows))
  
  for (i in seq_along(event_rows)) {
    dt_loo <- dt_base[-event_rows[i]]
    res <- run_spec(dt_loo, trade, extra_terms = NULL, cluster = "~ISO",
                    estimator = "ppml", label = paste0("loo_event_", i))
    loo_est[i] <- if (is.null(res)) NA_real_ else res$estimate
  }
  
  results[[length(results) + 1]] <- data.table(
    test = "leave_one_event_out_summary",
    trade = trade,
    estimate = mean(loo_est, na.rm = TRUE),
    se = sd(loo_est, na.rm = TRUE),
    pvalue = NA_real_,
    n = length(na.omit(loo_est)),
    note = sprintf("平均=%.4f, min=%.4f, max=%.4f, 负号比例=%.2f",
                   mean(loo_est, na.rm = TRUE),
                   min(loo_est, na.rm = TRUE),
                   max(loo_est, na.rm = TRUE),
                   mean(loo_est < 0, na.rm = TRUE))
  )
}

# ============================================================================
# 3. 保存
# ============================================================================
out <- rbindlist(results, use.names = TRUE, fill = TRUE)
out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(out, file.path(OUT_DIR, "09c_robustness_economic_cooperation.csv"))
cat(sprintf("✓ 09c_robustness_economic_cooperation.csv 已保存 (%d 行)\n", nrow(out)))
print(out[, .(test, trade_label, estimate, se, pvalue, sig, n, note)])
