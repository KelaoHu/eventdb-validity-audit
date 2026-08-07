# 04_event_study_did.R

rm(list = ls())

pkgs <- c("fixest", "data.table", "dplyr", "ggplot2", "tidyr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
FIG_DIR <- file.path(TEST_DIR, "图片")
MID_DIR <- file.path(TEST_DIR, "中间数据")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/5] 读取数据并构造 FTA 事件时间...\n")
panel_full <- fread(file = file.path(MID_DIR, "panel_for_robustness.csv"), encoding = "UTF-8")
panel_full[, YearMonth := as.Date(YearMonth)]
panel_full[, fta_date := as.Date(fta_date)]

# 对 FTA 分析只需国家-月份层面，聚合四个政治数据库的经济变量
panel_did <- panel_full[, .(
  Country = first(Country),
  Trade_Total = first(Trade_Total),
  Trade_Exports = first(Trade_Exports),
  Trade_Imports = first(Trade_Imports),
  ln_GDP_product = first(ln_GDP_product),
  ln_ER = first(ln_ER),
  FTA_Dummy = max(FTA_Dummy, na.rm = TRUE),
  Post_FTA = max(Post_FTA, na.rm = TRUE),
  Has_FTA = max(Has_FTA, na.rm = TRUE),
  fta_date = first(fta_date)
), by = .(ISO, YearMonth)]

# 事件时间（月），以 FTA 生效当月为 0
panel_did[, ym_yr := as.numeric(format(YearMonth, "%Y"))]
panel_did[, ym_mo := as.numeric(format(YearMonth, "%m"))]
panel_did[, fta_yr := as.numeric(format(fta_date, "%Y"))]
panel_did[, fta_mo := as.numeric(format(fta_date, "%m"))]
panel_did[, event_time := (ym_yr - fta_yr) * 12 + (ym_mo - fta_mo)]

# 仅保留已签订 FTA 的国家，并在 [-12, +12] 事件窗口内
panel_event <- panel_did[Has_FTA == 1 & !is.na(event_time) &
                           event_time >= -12 & event_time <= 12]
panel_event[, event_time := as.factor(event_time)]

TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")

# ----------------------------------------------------------------------------
# 2) 事件研究（Event Study）
# ----------------------------------------------------------------------------
cat("[2/5] 估计 FTA 事件研究模型...\n")

event_results <- list()
event_plots <- list()

for (trade in TRADE_VARS) {
  dt_fit <- panel_event[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER)]
  if (nrow(dt_fit) < 200 || uniqueN(dt_fit$ISO) < 3) next
  
  formula_str <- sprintf("%s ~ i(event_time, ref = -1) + ln_GDP_product + ln_ER | ISO + YearMonth", trade)
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) next
  
  ct <- coeftable(fit)
  # 提取事件时间系数
  et_levels <- setdiff(as.character(-24:24), "-1")
  coef_dt <- data.table(
    event_time = as.integer(et_levels),
    estimate = NA_real_,
    se = NA_real_,
    pvalue = NA_real_
  )
  coef_dt <- coef_dt[event_time >= -12 & event_time <= 12 & event_time != -1]
  for (i in seq_len(nrow(coef_dt))) {
    vname <- paste0("event_time::", coef_dt$event_time[i], ":", trade)
    # fixest i() 默认命名：i(event_time, ref=-1) 生成 "event_time::-24" 等
    vname2 <- paste0("event_time::", coef_dt$event_time[i])
    target <- if (vname2 %in% rownames(ct)) vname2 else if (vname %in% rownames(ct)) vname else NA_character_
    if (!is.na(target)) {
      coef_dt[i, estimate := as.numeric(ct[target, "Estimate"])]
      coef_dt[i, se := as.numeric(ct[target, "Std. Error"])]
      coef_dt[i, pvalue := as.numeric(ct[target, "Pr(>|z|)"])]
    }
  }
  coef_dt[, trade := trade]
  coef_dt[, pct_change := (exp(estimate) - 1) * 100]
  coef_dt[, ci_lower := (exp(estimate - 1.96 * se) - 1) * 100]
  coef_dt[, ci_upper := (exp(estimate + 1.96 * se) - 1) * 100]
  coef_dt[, n := nrow(dt_fit)]
  coef_dt[, n_country := uniqueN(dt_fit$ISO)]
  event_results[[length(event_results) + 1]] <- coef_dt
}

event_dt <- rbindlist(event_results, use.names = TRUE, fill = TRUE)
fwrite(event_dt, file.path(OUT_DIR, "fta_event_study_coefficients.csv"))
cat(sprintf("✓ fta_event_study_coefficients.csv 已保存 (%d 行)\n", nrow(event_dt)))

# 事件研究图
if (nrow(event_dt) > 0) {
  event_dt[, trade_label := factor(trade,
                                    levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                                    labels = c("总贸易", "出口", "进口"))]
  
  p_event <- ggplot(event_dt[!is.na(estimate)], aes(x = event_time, y = pct_change)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_vline(xintercept = -1, linetype = "dotted", color = "red") +
    geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.4, alpha = 0.6) +
    geom_point(size = 2, color = "steelblue") +
    facet_wrap(~ trade_label, ncol = 1, scales = "free_y") +
    scale_x_continuous(breaks = seq(-12, 12, 3), limits = c(-12, 12)) +
    labs(
      title = "FTA 生效的事件研究：相对 FTA 生效月份的贸易动态",
      subtitle = "以生效前一月（event_time = -1）为参照；窗口 [-12, +12] 个月；误差线为 95% 置信区间",
      x = "距 FTA 生效的月份",
      y = "贸易额变化百分比（%）"
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none",
          strip.text = element_text(face = "bold", size = 11))
  
  ggsave(file.path(FIG_DIR, "fig05_fta_event_study.png"), p_event, width = 10, height = 10, dpi = 300)
  cat("✓ fig05_fta_event_study.png\n")
}

# ----------------------------------------------------------------------------
# 3) 经典 DID
# ----------------------------------------------------------------------------
cat("[3/5] 估计 FTA 双重差分模型...\n")

did_results <- list()
for (trade in TRADE_VARS) {
  dt_fit <- panel_did[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER)]
  if (nrow(dt_fit) < 200) next
  
  formula_str <- sprintf("%s ~ Post_FTA + ln_GDP_product + ln_ER | ISO + YearMonth", trade)
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) next
  
  ct <- coeftable(fit)
  vname <- "Post_FTA"
  if (!(vname %in% rownames(ct))) next
  
  est <- as.numeric(ct[vname, "Estimate"])
  se <- as.numeric(ct[vname, "Std. Error"])
  pv <- as.numeric(ct[vname, "Pr(>|z|)"])
  
  did_results[[length(did_results) + 1]] <- data.table(
    trade = trade,
    estimate = est,
    se = se,
    pvalue = pv,
    pct_change = (exp(est) - 1) * 100,
    ci_lower = (exp(est - 1.96 * se) - 1) * 100,
    ci_upper = (exp(est + 1.96 * se) - 1) * 100,
    n = nrow(dt_fit),
    n_country = uniqueN(dt_fit$ISO)
  )
}

did_dt <- rbindlist(did_results, use.names = TRUE, fill = TRUE)
fwrite(did_dt, file.path(OUT_DIR, "fta_did_main_results.csv"))
cat(sprintf("✓ fta_did_main_results.csv 已保存 (%d 行)\n", nrow(did_dt)))
print(did_dt)

# DID 效应图
if (nrow(did_dt) > 0) {
  did_dt[, trade_label := factor(trade,
                                  levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                                  labels = c("总贸易", "出口", "进口"))]
  
  p_did <- ggplot(did_dt, aes(x = trade_label, y = pct_change)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2, linewidth = 1) +
    geom_point(size = 4, color = "steelblue") +
    geom_text(aes(label = sprintf("%.1f%%", pct_change)), vjust = -0.8, size = 3.5) +
    labs(
      title = "FTA 生效的 DID 平均处理效应",
      subtitle = "基于 PPML 固定效应模型；误差线为 95% 置信区间",
      x = "贸易指标",
      y = "贸易额变化百分比（%）"
    ) +
    theme_minimal(base_size = 12)
  
  ggsave(file.path(FIG_DIR, "fig06_fta_did_effect.png"), p_did, width = 8, height = 6, dpi = 300)
  cat("✓ fig06_fta_did_effect.png\n")
}

# ----------------------------------------------------------------------------
# 4) Placebo 检验：将 FTA 生效时间整体平移 24 个月
# ----------------------------------------------------------------------------
cat("[4/5] 进行 FTA 生效时间平移 24 个月的 Placebo 检验...\n")

panel_placebo <- copy(panel_did)
# 仅对 Has_FTA 的国家，把 fta_date 推后 24 个月
panel_placebo[Has_FTA == 1, fta_date_placebo := {
  yr <- as.numeric(format(fta_date, "%Y")) + 2
  mo <- as.numeric(format(fta_date, "%m"))
  as.Date(paste0(yr, "-", sprintf("%02d", mo), "-01"))
}]
panel_placebo[, Post_FTA_Placebo := as.integer(YearMonth >= fta_date_placebo)]
panel_placebo[is.na(Post_FTA_Placebo), Post_FTA_Placebo := 0]

placebo_results <- list()
for (trade in TRADE_VARS) {
  dt_fit <- panel_placebo[!is.na(get(trade)) & !is.na(ln_GDP_product) & !is.na(ln_ER)]
  if (nrow(dt_fit) < 200) next
  
  formula_str <- sprintf("%s ~ Post_FTA_Placebo + ln_GDP_product + ln_ER | ISO + YearMonth", trade)
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) next
  
  ct <- coeftable(fit)
  vname <- "Post_FTA_Placebo"
  if (!(vname %in% rownames(ct))) next
  
  est <- as.numeric(ct[vname, "Estimate"])
  se <- as.numeric(ct[vname, "Std. Error"])
  pv <- as.numeric(ct[vname, "Pr(>|z|)"])
  
  placebo_results[[length(placebo_results) + 1]] <- data.table(
    trade = trade,
    estimate = est,
    se = se,
    pvalue = pv,
    pct_change = (exp(est) - 1) * 100,
    ci_lower = (exp(est - 1.96 * se) - 1) * 100,
    ci_upper = (exp(est + 1.96 * se) - 1) * 100,
    n = nrow(dt_fit),
    n_country = uniqueN(dt_fit$ISO)
  )
}

placebo_dt <- rbindlist(placebo_results, use.names = TRUE, fill = TRUE)
placebo_dt[, type := "Placebo (+24m)"]
placebo_dt[, trade_label := factor(trade,
                                    levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                                    labels = c("总贸易", "出口", "进口"))]
did_dt[, type := "Actual"]
compare_dt <- rbindlist(list(did_dt, placebo_dt), use.names = TRUE, fill = TRUE)
fwrite(compare_dt, file.path(OUT_DIR, "fta_did_placebo_results.csv"))
cat(sprintf("✓ fta_did_placebo_results.csv 已保存 (%d 行)\n", nrow(compare_dt)))
print(compare_dt)

# Placebo 对比图
if (nrow(compare_dt) > 0) {
  compare_dt[, trade_label := factor(trade,
                                      levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                                      labels = c("总贸易", "出口", "进口"))]
  compare_dt[, type := factor(type, levels = c("Actual", "Placebo (+24m)"))]
  
  p_placebo <- ggplot(compare_dt, aes(x = trade_label, y = pct_change, color = type,
                                       group = type)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2,
                  position = position_dodge(width = 0.4), linewidth = 1) +
    geom_point(size = 3, position = position_dodge(width = 0.4)) +
    scale_color_manual(values = c("Actual" = "steelblue", "Placebo (+24m)" = "coral")) +
    labs(
      title = "FTA DID：真实效应 vs Placebo（生效时间推后 24 个月）",
      x = "贸易指标",
      y = "贸易额变化百分比（%）",
      color = "估计类型"
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom")
  
  ggsave(file.path(FIG_DIR, "fig07_fta_did_placebo.png"), p_placebo, width = 8, height = 6, dpi = 300)
  cat("✓ fig07_fta_did_placebo.png\n")
}

cat("FTA 事件研究与 DID 分析完成。\n")
