# 01_plot_baseline_effects.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(readr)

df <- read_csv(file.path(TEST_DIR, "检验结果CSV", "01_baseline_event_effects.csv"), show_col_types = FALSE)
df$variable <- factor(df$variable, levels = c("Event_Positive", "Event_Negative", "Event_Neutral"),
                      labels = c("正向事件", "负向事件", "中性事件"))
df$trade_label <- factor(df$trade_label, levels = c("总贸易", "出口", "进口"))

p <- ggplot(df, aes(x = estimate, y = variable, color = variable)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se), height = 0.2, linewidth = 0.8) +
  facet_wrap(~ trade_label, ncol = 1) +
  labs(title = "事件基准效应：正/负/中性事件对双边贸易的影响",
       subtitle = "PPML-HDFE（国家+时间固定效应，聚类到国家）",
       x = "系数（对贸易额的百分比影响）", y = NULL,
       caption = "误差线为 95% 置信区间；* p<0.10, ** p<0.05, *** p<0.01") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none",
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold"),
        strip.text = element_text(face = "bold", size = 12)) +
  scale_color_manual(values = c("正向事件" = "#2E8B57", "负向事件" = "#D62728", "中性事件" = "#7F7F7F"))

ggsave(file.path(OUT_DIR, "fig01_baseline_event_effects.png"), p, width = 8, height = 6, dpi = 300)
cat(sprintf("✓ fig01_baseline_event_effects.png 已保存\n"))
