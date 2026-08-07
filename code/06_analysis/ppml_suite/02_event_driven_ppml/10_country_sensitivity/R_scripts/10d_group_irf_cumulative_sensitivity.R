# 10d_group_irf_cumulative_sensitivity.R

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

HORIZONS <- c(0, 1, 3, 6, 12)

cat("[1/4] 读取事件面板并生成分组标签...\n")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

# 确保滞后变量存在
panel_ev <- make_event_lags(panel_ev, c("Event_Positive", "Event_Negative", "Event_Neutral"), horizons = HORIZONS)

# 分组标签（时间不变或取均值）
developed <- c("US", "JP", "DE", "GB", "FR", "IT", "CA", "AU", "ES", "NL", "BE", "KR", "SG")
panel_ev[, developed := as.integer(ISO %in% developed)]

avg_trade <- panel_ev[, .(avg_trade = mean(Trade_Total, na.rm = TRUE)), by = ISO]
qts <- quantile(avg_trade$avg_trade, probs = c(1/3, 2/3), na.rm = TRUE)
avg_trade[, trade_dep := fcase(
  avg_trade <= qts[1], "low",
  avg_trade <= qts[2], "medium",
  default = "high"
)]
panel_ev <- merge(panel_ev, avg_trade[, .(ISO, trade_dep)], by = "ISO", all.x = TRUE)

ever_fta <- panel_ev[, .(ever_fta = max(FTA_Dummy, na.rm = TRUE)), by = ISO]
panel_ev <- merge(panel_ev, ever_fta, by = "ISO", all.x = TRUE)

# 定义分组维度
group_dims <- list(
  developed = list(var = "developed", labels = c("0" = "发展中", "1" = "发达"), type = "binary"),
  ever_fta = list(var = "ever_fta", labels = c("0" = "无FTA", "1" = "有FTA"), type = "binary"),
  trade_dep = list(var = "trade_dep", labels = c("low" = "低依存", "medium" = "中依存", "high" = "高依存"), type = "multi")
)

# ----------------------------------------------------------------------------
# 2) 分组 IRF
# ----------------------------------------------------------------------------
cat("[2/4] 分组 IRF 估计...\n")

run_group_irf <- function(dt, trade, event_base, h, group_name, group_label) {
  x_var <- if (h == 0) event_base else paste0(event_base, "_L", h)
  if (!(x_var %in% names(dt))) return(NULL)
  dt_fit <- dt[!is.na(get(trade)) & !is.na(get(x_var)) &
                 !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
  if (nrow(dt_fit) < 50) return(NULL)
  
  # 若按 ever_fta 分组，组内 FTA_Dummy 为常数，需剔除控制变量避免共线警告
  controls_use <- CONTROLS
  if (group_name == "ever_fta" && length(unique(dt_fit$FTA_Dummy)) == 1L) {
    controls_use <- setdiff(CONTROLS, "FTA_Dummy")
  }
  
  formula_str <- sprintf("%s ~ %s + %s | ISO + YearMonth", trade, x_var, paste(controls_use, collapse = " + "))
  fit <- tryCatch(
    fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)
  ct <- coeftable(fit)
  if (!(x_var %in% rownames(ct))) return(NULL)
  
  data.table(
    dimension = group_name,
    group = group_label,
    trade = trade,
    event = event_base,
    horizon = h,
    estimate = as.numeric(ct[x_var, "Estimate"]),
    se = as.numeric(ct[x_var, "Std. Error"]),
    pvalue = as.numeric(ct[x_var, "Pr(>|z|)"]),
    n = nrow(dt_fit),
    n_country = uniqueN(dt_fit$ISO)
  )
}

results <- list()
for (trade in TRADE_VARS) {
  for (dim_name in names(group_dims)) {
    dim_info <- group_dims[[dim_name]]
    groups <- sort(unique(panel_ev[[dim_info$var]]))
    for (g in groups) {
      g_label <- if (!is.null(dim_info$labels) && as.character(g) %in% names(dim_info$labels)) dim_info$labels[[as.character(g)]] else as.character(g)
      dt_g <- panel_ev[get(dim_info$var) == g]
      for (ev in c("Event_Positive", "Event_Negative", "Event_Neutral")) {
        for (h in HORIZONS) {
          res <- run_group_irf(dt_g, trade, ev, h, dim_name, g_label)
          if (!is.null(res)) results[[length(results) + 1]] <- res
        }
      }
    }
  }
}

irf_out <- rbindlist(results, use.names = TRUE)
irf_out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
irf_out[, ci_lower := estimate - 1.96 * se]
irf_out[, ci_upper := estimate + 1.96 * se]
irf_out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(irf_out, file.path(OUT_DIR, "10d_group_irf.csv"))
cat(sprintf("✓ 10d_group_irf.csv 已保存 (%d 行)\n", nrow(irf_out)))

# ----------------------------------------------------------------------------
# 3) 组间差异 Wald 检验（全样本交互项）
# ----------------------------------------------------------------------------
cat("[3/4] 组间差异 Wald 检验...\n")

wald_results <- list()
for (trade in TRADE_VARS) {
  for (dim_name in names(group_dims)) {
    dim_info <- group_dims[[dim_name]]
    if (dim_info$type == "multi") next  # 多组 Wald 较复杂，此处先处理二分组
    gvar <- dim_info$var
    
    for (ev in c("Event_Positive", "Event_Negative", "Event_Neutral")) {
      for (h in HORIZONS) {
        x_var <- if (h == 0) ev else paste0(ev, "_L", h)
        if (!(x_var %in% names(panel_ev))) next
        inter_name <- paste0(x_var, "_x_", gvar)
        panel_ev[, (inter_name) := get(x_var) * get(gvar)]
        
        dt_fit <- panel_ev[!is.na(get(trade)) & !is.na(get(x_var)) & !is.na(get(inter_name)) &
                             !is.na(ln_GDP_product) & !is.na(ln_ER) & !is.na(FTA_Dummy)]
        formula_str <- sprintf("%s ~ %s + %s + %s | ISO + YearMonth", trade, x_var, inter_name, paste(CONTROLS, collapse = " + "))
        fit <- tryCatch(
          fepois(as.formula(formula_str), data = dt_fit, cluster = ~ISO, glm.iter = 100),
          error = function(e) NULL
        )
        
        if (!is.null(fit) && inter_name %in% rownames(coeftable(fit))) {
          w <- tryCatch(wald(fit, inter_name), error = function(e) NULL)
          p_wald <- if (!is.null(w) && "p" %in% names(w)) as.numeric(w$p) else NA_real_
          wald_results[[length(wald_results) + 1]] <- data.table(
            dimension = dim_name,
            trade = trade,
            event = ev,
            horizon = h,
            wald_pvalue = p_wald,
            n = nrow(dt_fit)
          )
        }
        panel_ev[, (inter_name) := NULL]
      }
    }
  }
}

wald_out <- rbindlist(wald_results, use.names = TRUE)
if (nrow(wald_out) > 0) {
  wald_out[, sig := ifelse(wald_pvalue < 0.01, "***", ifelse(wald_pvalue < 0.05, "**", ifelse(wald_pvalue < 0.10, "*", "")))]
  fwrite(wald_out, file.path(OUT_DIR, "10d_group_irf_wald.csv"))
  cat(sprintf("✓ 10d_group_irf_wald.csv 已保存 (%d 行)\n", nrow(wald_out)))
  print(wald_out[wald_pvalue < 0.10][order(dimension, trade, event, horizon)])
}

# ----------------------------------------------------------------------------
# 4) 累积敏感度指数
# ----------------------------------------------------------------------------
cat("[4/4] 计算累积敏感度指数...\n")

cum_sens <- irf_out[, .(
  cum_estimate = sum(estimate, na.rm = TRUE),
  cum_se = sqrt(sum(se^2, na.rm = TRUE)),
  n_h = .N,
  n_country = first(n_country)
), by = .(dimension, group, trade, event)]
cum_sens[, cum_pvalue := 2 * pnorm(-abs(cum_estimate / cum_se))]
cum_sens[, sig := ifelse(cum_pvalue < 0.01, "***", ifelse(cum_pvalue < 0.05, "**", ifelse(cum_pvalue < 0.10, "*", "")))]
cum_sens[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(cum_sens, file.path(OUT_DIR, "10d_cumulative_sensitivity.csv"))
cat(sprintf("✓ 10d_cumulative_sensitivity.csv 已保存 (%d 行)\n", nrow(cum_sens)))
print(cum_sens[order(dimension, trade, event, group)])

# ----------------------------------------------------------------------------
# 5) 绘图
# ----------------------------------------------------------------------------
cat("绘图...\n")

plot_dt <- irf_out[event %in% c("Event_Positive", "Event_Negative")]
plot_dt[, event_label := ifelse(event == "Event_Positive", "正向事件", "负向事件")]
plot_dt[, group_event := paste(group, event_label, sep = " | ")]

p <- ggplot(plot_dt, aes(x = horizon, y = estimate, color = group_event, group = group_event)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(ymin = ci_lower, ymax = ci_upper), position = position_dodge(width = 0.4), linewidth = 0.6, fatten = 2) +
  geom_line(position = position_dodge(width = 0.4), linewidth = 0.5) +
  facet_grid(trade_label ~ dimension, scales = "free_y") +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "国家分组动态 IRF：政治事件对贸易的影响",
    subtitle = "h = 0,1,3,6,12 个月；误差线为 95% 置信区间",
    x = "滞后月份",
    y = "系数",
    color = "分组 | 事件"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 9)
  )

ggsave(file.path(FIG_DIR, "10d_group_irf.png"), p, width = 14, height = 10, dpi = 300)
cat("✓ 已保存 10d_group_irf.png\n")
