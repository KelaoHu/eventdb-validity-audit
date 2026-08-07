# 10b_country_sensitivity_meta_regression.R

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

cat("[1/3] 读取 02_04 国家异质性系数与事件面板...\n")
cty_coef <- fread(file.path(PPML_DIR, "04_国家异质性", "检验结果CSV", "04_country_heterogeneity.csv"), encoding = "UTF-8")
setnames(cty_coef, sub("^\ufeff", "", names(cty_coef)))

panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据", "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))

# 国家特征（时间不变或取均值）
developed <- c("US", "JP", "DE", "GB", "FR", "IT", "CA", "AU", "ES", "NL", "BE", "KR", "SG")
panel_ev[, developed := as.integer(ISO %in% developed)]
panel_ev[, us_ally := as.integer(ISO %in% c("US", "JP", "AU", "CA", "GB", "KR", "DE", "FR", "IT", "ES", "NL", "BE"))]

avg_trade <- panel_ev[, .(avg_trade = mean(Trade_Total, na.rm = TRUE)), by = ISO]
avg_trade[, z_trade_dep := scale(avg_trade)[, 1]]

cty_chars <- panel_ev[, .(
  FTA = mean(FTA_Dummy, na.rm = TRUE),
  developed = max(developed, na.rm = TRUE),
  us_ally = max(us_ally, na.rm = TRUE)
), by = .(ISO, Country)]
cty_chars <- merge(cty_chars, avg_trade[, .(ISO, z_trade_dep)], by = "ISO", all.x = TRUE)

# 区域
cty_chars[, region := fcase(
  ISO %in% c("JP", "KR", "IN", "ID", "TH", "MY", "PH", "VN", "SG", "AE", "SA"), "Asia_MiddleEast",
  ISO %in% c("DE", "GB", "FR", "IT", "ES", "NL", "BE", "RU"), "Europe",
  ISO %in% c("US", "CA", "MX", "BR"), "Americas",
  default = "Other"
)]

# ----------------------------------------------------------------------------
# 2) 构造国家敏感度指标（基于 02_04 系数）
#    sensitivity = beta_Negative - beta_Positive
# ----------------------------------------------------------------------------
cat("[2/3] 构造国家敏感度指标...\n")

build_sensitivity <- function(trade_var) {
  pos <- cty_coef[trade == trade_var & variable == "Event_Positive", .(ISO, b_pos = estimate, se_pos = se)]
  neg <- cty_coef[trade == trade_var & variable == "Event_Negative", .(ISO, b_neg = estimate, se_neg = se)]
  dt <- merge(pos, neg, by = "ISO", all = TRUE)
  dt[, sensitivity := b_neg - b_pos]
  dt[, se_sens := sqrt(se_pos^2 + se_neg^2)]
  dt[, precision := 1 / (se_sens^2)]
  dt[, trade := trade_var]
  dt
}

sens_list <- lapply(TRADE_VARS, build_sensitivity)
sens_dt <- rbindlist(sens_list, use.names = TRUE)
sens_dt <- sens_dt[!is.na(sensitivity) & !is.na(se_sens) & se_sens > 0]
sens_dt <- merge(sens_dt, cty_chars, by = "ISO", all.x = TRUE)

fwrite(sens_dt, file.path(OUT_DIR, "10b_country_sensitivity_for_meta.csv"))
cat(sprintf("✓ 10b_country_sensitivity_for_meta.csv 已保存 (%d 行)\n", nrow(sens_dt)))

# ----------------------------------------------------------------------------
# 3) 两阶段 Meta-回归
# ----------------------------------------------------------------------------
cat("[3/3] 两阶段 Meta-回归...\n")

run_meta <- function(dt, trade_var) {
  d <- dt[trade == trade_var]
  if (nrow(d) < 10) return(NULL)
  
  # 模型 1：仅国家特征
  f1 <- lm(sensitivity ~ FTA + developed + z_trade_dep, data = d, weights = precision)
  # 模型 2：加入区域（欧洲为参照）
  f2 <- lm(sensitivity ~ FTA + developed + z_trade_dep + factor(region), data = d, weights = precision)
  # 模型 3：不加权（稳健性）
  f3 <- lm(sensitivity ~ FTA + developed + z_trade_dep, data = d)
  
  summarize <- function(fit, label) {
    s <- summary(fit)
    coefs <- as.data.frame(s$coefficients)
    setDT(coefs, keep.rownames = "term")
    coefs[, trade := trade_var]
    coefs[, model := label]
    coefs[, r_squared := s$r.squared]
    coefs[, adj_r_squared := s$adj.r.squared]
    coefs[, f_statistic := s$fstatistic[1]]
    coefs[, n_obs := nrow(d)]
    setnames(coefs, c("term", "estimate", "se", "t_value", "pvalue", "trade", "model", "r_squared", "adj_r_squared", "f_statistic", "n_obs"))
    coefs
  }
  
  rbindlist(list(
    summarize(f1, "weighted_FE_only"),
    summarize(f2, "weighted_with_region"),
    summarize(f3, "unweighted_FE_only")
  ), use.names = TRUE, fill = TRUE)
}

meta_results <- lapply(TRADE_VARS, function(tv) run_meta(sens_dt, tv))
meta_out <- rbindlist(meta_results, use.names = TRUE, fill = TRUE)
meta_out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]

fwrite(meta_out, file.path(OUT_DIR, "10b_meta_regression.csv"))
cat(sprintf("✓ 10b_meta_regression.csv 已保存 (%d 行)\n", nrow(meta_out)))
print(meta_out[order(trade, model, term)])

# ----------------------------------------------------------------------------
# 4) 绘图：拟合 vs 观测敏感度
# ----------------------------------------------------------------------------
cat("绘图...\n")

plot_list <- list()
for (tv in TRADE_VARS) {
  d <- sens_dt[trade == tv]
  if (nrow(d) < 5) next
  fit <- lm(sensitivity ~ FTA + developed + z_trade_dep, data = d, weights = precision)
  d[, fitted := fitted(fit)]
  d[, trade_label := factor(tv, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]
  plot_list[[tv]] <- d
}

plot_dt <- rbindlist(plot_list, use.names = TRUE, fill = TRUE)

p <- ggplot(plot_dt, aes(x = fitted, y = sensitivity)) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "grey50") +
  geom_point(aes(color = region, size = precision), alpha = 0.7) +
  geom_text(aes(label = ISO), size = 3, check_overlap = TRUE, vjust = -0.5) +
  facet_wrap(~trade_label, scales = "free") +
  labs(
    title = "Meta-回归：国家特征对国家敏感度的解释力",
    subtitle = "点大小代表估计精度（precision）；虚线为 45° 参考线",
    x = "拟合敏感度（国家特征预测值）",
    y = "观测敏感度（beta_Negative - beta_Positive）",
    color = "区域"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(FIG_DIR, "10b_meta_fitted_vs_observed.png"), p, width = 12, height = 5, dpi = 300)
cat("✓ 已保存 10b_meta_fitted_vs_observed.png\n")
