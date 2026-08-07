# 10a_country_sensitivity_interactions_and_jackknife.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取事件面板并构建连续国家特征...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# 国家特征（随时间不变的代理变量）
developed <- c("US", "JP", "DE", "GB", "FR", "IT", "CA", "AU", "ES", "NL", "BE", "KR", "SG")
panel_ev[, developed := as.integer(ISO %in% developed)]
panel_ev[, us_ally := as.integer(ISO %in% c("US", "JP", "AU", "CA", "GB", "KR", "DE", "FR", "IT", "ES", "NL", "BE"))]

# 连续贸易依存度：该国对华平均月度总贸易的标准化 z-score
avg_trade <- panel_ev[, .(avg_trade = mean(Trade_Total, na.rm = TRUE)), by = ISO]
avg_trade[, z_trade_dep := scale(avg_trade)[, 1]]
panel_ev <- merge(panel_ev, avg_trade[, .(ISO, z_trade_dep)], by = "ISO", all.x = TRUE)

# 区域（用于 leave-one-out 标注，不作为交互主项）
panel_ev[, region := fcase(
  ISO %in% c("JP", "KR", "IN", "ID", "TH", "MY", "PH", "VN", "SG", "AE", "SA"), "Asia_MiddleEast",
  ISO %in% c("DE", "GB", "FR", "IT", "ES", "NL", "BE", "RU"), "Europe",
  ISO %in% c("US", "CA", "MX", "BR"), "Americas",
  default = "Other"
)]

# 用于交互的核心事件变量
EVENT_VARS <- c("Event_Positive", "Event_Negative", "Event_Neutral")
CHAR_VARS <- c("z_trade_dep", "FTA_Dummy", "developed", "us_ally")

# 构建交互项
for (ev in EVENT_VARS) {
  for (c in CHAR_VARS) {
    panel_ev[, (paste0(ev, "_x_", c)) := get(ev) * get(c)]
  }
}

# ----------------------------------------------------------------------------
# 2) 连续国家特征交互项回归
# ----------------------------------------------------------------------------
cat("[2/3] 连续国家特征交互项回归...\n")

run_interactions <- function(dt, trade) {
  dt_fit <- dt[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  for (v in c(EVENT_VARS, unlist(lapply(EVENT_VARS, function(ev) paste0(ev, "_x_", CHAR_VARS))))) {
    dt_fit <- dt_fit[!is.na(get(v))]
  }
  
  rhs <- c(EVENT_VARS, unlist(lapply(EVENT_VARS, function(ev) paste0(ev, "_x_", CHAR_VARS))), CONTROLS)
  formula_str <- sprintf("%s ~ %s | ISO + YearMonth", trade, paste(rhs, collapse = " + "))
  
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  
  res <- data.table(
    trade = trade,
    variable = rownames(ct),
    estimate = as.numeric(ct[, "Estimate"]),
    se = as.numeric(ct[, "Std. Error"]),
    pvalue = as.numeric(ct[, "Pr(>|z|)"]),
    n = nrow(dt_fit)
  )
  res[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
  return(res)
}

inter_results <- list()
for (trade in TRADE_VARS) {
  res <- run_interactions(panel_ev, trade)
  if (!is.null(res)) inter_results[[length(inter_results) + 1]] <- res
}
inter_out <- rbindlist(inter_results, use.names = TRUE)
fwrite(inter_out, file.path(OUT_DIR, "10a_interactions.csv"))
cat(sprintf("✓ 10a_interactions.csv 已保存 (%d 行)\n", nrow(inter_out)))
print(inter_out[grepl("_x_", variable)][order(trade, variable)])

# ----------------------------------------------------------------------------
# 3) leave-one-country-out（Jackknife）稳健性
# ----------------------------------------------------------------------------
cat("[3/3] leave-one-country-out 稳健性...\n")

countries <- sort(unique(panel_ev$ISO))
jack_results <- list()
base_inter_terms <- unlist(lapply(EVENT_VARS, function(ev) paste0(ev, "_x_", CHAR_VARS)))

for (drop_cty in countries) {
  dt_j <- panel_ev[ISO != drop_cty]
  for (trade in TRADE_VARS) {
    res <- run_interactions(dt_j, trade)
    if (is.null(res)) next
    sub <- res[variable %in% base_inter_terms][, .(trade, variable, estimate, pvalue, sig)]
    sub[, dropped := drop_cty]
    jack_results[[length(jack_results) + 1]] <- sub
  }
}

jack_out <- rbindlist(jack_results, use.names = TRUE)
fwrite(jack_out, file.path(OUT_DIR, "10a_jackknife.csv"))
cat(sprintf("✓ 10a_jackknife.csv 已保存 (%d 行)\n", nrow(jack_out)))

# 汇总：每个交互项在删除各国后显著性/符号变化情况
base_full <- inter_out[variable %in% base_inter_terms][, .(trade, variable, base_est = estimate, base_p = pvalue, base_sig = sig)]
jack_summary <- jack_out[, .(
  n_dropped = .N,
  sign_changed = sum(estimate * base_full[trade == .BY[[1]] & variable == .BY[[2]], base_est] < 0, na.rm = TRUE),
  sig_lost = sum(base_full[trade == .BY[[1]] & variable == .BY[[2]], base_sig] != "" & sig == "", na.rm = TRUE),
  est_min = min(estimate, na.rm = TRUE),
  est_max = max(estimate, na.rm = TRUE)
), by = .(trade, variable)]
jack_summary <- merge(jack_summary, base_full, by = c("trade", "variable"), all.x = TRUE)
fwrite(jack_summary, file.path(OUT_DIR, "10a_jackknife_summary.csv"))
cat("✓ 10a_jackknife_summary.csv 已保存\n")
print(jack_summary[order(trade, variable)])

# ----------------------------------------------------------------------------
# 4) 绘图：Jackknife 系数稳定性
# ----------------------------------------------------------------------------
cat("绘图...\n")
jack_out[, term_label := gsub("Event_Negative_x_|Event_Positive_x_|Event_Neutral_x_", "", variable)]
jack_out[, event_label := gsub("_x_.*$", "", variable)]
jack_out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

# 只绘制在基准模型中显著的交互项，避免图过于拥挤
sig_terms <- inter_out[grepl("_x_", variable) & sig != "", .(trade, variable)]
plot_dt <- merge(jack_out, sig_terms, by = c("trade", "variable"))

if (nrow(plot_dt) > 0) {
  p <- ggplot(plot_dt, aes(x = dropped, y = estimate, color = event_label, group = event_label)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_point(size = 2) +
    geom_line(linewidth = 0.4) +
    facet_grid(trade_label ~ term_label, scales = "free_y") +
    labs(
      title = "连续国家特征交互项的 leave-one-country-out 稳健性",
      subtitle = "仅显示基准模型中显著的交互项；点为删除该国后的系数",
      x = "被删除国家",
      y = "系数",
      color = "事件类型"
    ) +
    theme_minimal(base_size = 11) +
    theme(
      axis.text.x = element_text(angle = 90, hjust = 1, size = 7),
      legend.position = "bottom",
      strip.text = element_text(face = "bold", size = 9)
    )
  
  ggsave(file.path(FIG_DIR, "10a_jackknife_stability.png"), p, width = 14, height = 10, dpi = 300)
  cat("✓ 已保存 10a_jackknife_stability.png\n")
} else {
  cat("基准模型中无显著交互项，跳过绘图。\n")
}
