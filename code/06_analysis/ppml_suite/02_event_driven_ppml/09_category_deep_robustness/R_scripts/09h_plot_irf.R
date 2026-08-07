# 09h_plot_irf.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_PNG <- file.path(TEST_DIR, "图片", "fig09c_irf_key_categories.png")

library(ggplot2)
library(dplyr)
library(readr)

df <- read_csv(file.path(TEST_DIR, "检验结果CSV", "09d_irf_key_categories.csv"), show_col_types = FALSE)

# 标记预趋势
df$period <- ifelse(df$horizon < 0, "事前趋势", "事后效应")
df$period <- factor(df$period, levels = c("事前趋势", "事后效应"))

df$panel_label <- paste0(df$category, " → ", df$trade_label)

p <- ggplot(df, aes(x = horizon, y = estimate, color = period)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "gray70") +
  geom_line(aes(group = 1), color = "black", linewidth = 0.5) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  facet_wrap(~ panel_label, scales = "free_y", ncol = 2) +
  scale_color_manual(values = c("事前趋势" = "#1f77b4", "事后效应" = "#d62728")) +
  scale_x_continuous(breaks = c(-3, -2, -1, 0, 1, 3, 6, 12)) +
  labs(
    title = "关键事件类型动态 IRF",
    subtitle = "h<0 为事前趋势，h≥0 为事件后效应；误差线为 95% 置信区间",
    x = "滞后期（月）",
    y = "系数",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(OUT_PNG, p, width = 12, height = 10, dpi = 300)
cat(sprintf("✓ %s 已保存\n", OUT_PNG))
