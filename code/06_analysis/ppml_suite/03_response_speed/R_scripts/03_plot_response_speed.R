# 03_plot_response_speed.R

rm(list = ls())

pkgs <- c("data.table", "dplyr", "ggplot2", "tidyr")
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
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/5] 读取指标与系数数据...\n")
metrics <- fread(file.path(OUT_DIR, "response_speed_metrics.csv"), encoding = "UTF-8")
metrics[, window_midpoint := as.Date(window_midpoint)]

coef_dt <- fread(file.path(OUT_DIR, "window_coefficients.csv"), encoding = "UTF-8")

# ----------------------------------------------------------------------------
# 图 1：响应速度时变折线图
# ----------------------------------------------------------------------------
cat("[2/5] 绘制响应速度时变折线图...\n")

p1 <- ggplot(metrics[!is.na(avg_response_lag)],
             aes(x = window_midpoint, y = avg_response_lag, color = pol_label, group = pol_label)) +
  geom_hline(yintercept = 3, linetype = "dashed", color = "grey50") +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.5) +
  facet_grid(trade_label ~ db, scales = "free_y") +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "政治关系对贸易影响的响应速度时变趋势",
    subtitle = "平均响应滞后（月）= Σ|β_h|·h / Σ|β_h|；虚线为 3 个月参考线",
    x = "窗口中点年份",
    y = "平均响应滞后（月）",
    color = "政治关系指数"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 9),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave(file.path(FIG_DIR, "fig01_response_lag_trend.png"), p1, width = 16, height = 10, dpi = 300)
cat("✓ fig01_response_lag_trend.png\n")

# ----------------------------------------------------------------------------
# 图 2：早期 vs 近期斜率图
# ----------------------------------------------------------------------------
cat("[3/5] 绘制早期 vs 近期斜率图...\n")

first_last <- metrics[window_id %in% c(min(window_id), max(window_id))]
first_last[, period := ifelse(window_id == min(window_id), "早期 (2002-2006)", "近期 (2021-2025)")]
first_last[, period := factor(period, levels = c("早期 (2002-2006)", "近期 (2021-2025)"))]

p2 <- ggplot(first_last[!is.na(avg_response_lag)],
             aes(x = period, y = avg_response_lag, color = pol_label, group = pol_label)) +
  geom_point(size = 2) +
  geom_line(linewidth = 0.6) +
  facet_grid(trade_label ~ db, scales = "free_y") +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "响应速度：早期 vs 近期",
    subtitle = "第一个窗口（2002-2006）与最后一个窗口（2021-2025）的平均响应滞后对比",
    x = NULL,
    y = "平均响应滞后（月）",
    color = "政治关系指数"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 9)
  )

ggsave(file.path(FIG_DIR, "fig02_slope_early_recent.png"), p2, width = 16, height = 10, dpi = 300)
cat("✓ fig02_slope_early_recent.png\n")

# ----------------------------------------------------------------------------
# 图 3：山脊热力图（综合指数 Pol_Agg，跨四库）
# ----------------------------------------------------------------------------
cat("[4/5] 绘制综合指数山脊热力图...\n")

ridge_agg <- coef_dt[pol_var == "Pol_Agg"]
ridge_agg[, abs_coef := abs(estimate)]
window_info <- unique(metrics[, .(window_id, db, trade, window_midpoint, trade_label)])
ridge_agg <- merge(ridge_agg, window_info,
                   by = c("window_id", "db", "trade"), all.x = TRUE)
ridge_agg[, year_label := factor(format(window_midpoint, "%Y"))]
ridge_agg <- ridge_agg[!is.na(abs_coef)]

p3 <- ggplot(ridge_agg, aes(x = factor(h), y = year_label, fill = abs_coef)) +
  geom_tile(color = "white", linewidth = 0.2) +
  scale_fill_gradient(low = "white", high = "steelblue", na.value = "grey90", name = "|系数|") +
  facet_grid(trade_label ~ db, scales = "free_y") +
  labs(
    title = "综合政治指数（Pol_Agg）L0-L6 系数时空分布",
    subtitle = "颜色越深表示该滞后项对贸易的影响越强；每行为一个 60 个月滚动窗口",
    x = "滞后月份",
    y = "窗口中点年份"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 9),
    axis.text.y = element_text(size = 7)
  )

ggsave(file.path(FIG_DIR, "fig03_ridge_heatmap.png"), p3, width = 16, height = 12, dpi = 300)
cat("✓ fig03_ridge_heatmap.png\n")

# ----------------------------------------------------------------------------
# 图 4：方向指数山脊热力图（GDELT/ICEWS/Phoenix）
# ----------------------------------------------------------------------------
cat("[5/5] 绘制方向指数山脊热力图...\n")

ridge_dir <- coef_dt[pol_var %in% c("Pol_CHN_Partner", "Pol_Partner_CHN")]
ridge_dir[, abs_coef := abs(estimate)]
ridge_dir <- merge(ridge_dir, window_info,
                   by = c("window_id", "db", "trade"), all.x = TRUE)
ridge_dir[, year_label := factor(format(window_midpoint, "%Y"))]
ridge_dir <- ridge_dir[!is.na(abs_coef)]

p4 <- ggplot(ridge_dir, aes(x = factor(h), y = year_label, fill = abs_coef)) +
  geom_tile(color = "white", linewidth = 0.2) +
  scale_fill_gradient(low = "white", high = "darkred", na.value = "grey90", name = "|系数|") +
  facet_grid(trade_label ~ db + pol_var, scales = "free_y") +
  labs(
    title = "方向政治指数 L0-L6 系数时空分布",
    subtitle = "GDELT / ICEWS / Phoenix；颜色越深表示该滞后项影响越强",
    x = "滞后月份",
    y = "窗口中点年份"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold", size = 8),
    axis.text.y = element_text(size = 6),
    axis.text.x = element_text(size = 8)
  )

ggsave(file.path(FIG_DIR, "fig04_ridge_directional.png"), p4, width = 18, height = 12, dpi = 300)
cat("✓ fig04_ridge_directional.png\n")

cat("全部图表绘制完成。\n")
