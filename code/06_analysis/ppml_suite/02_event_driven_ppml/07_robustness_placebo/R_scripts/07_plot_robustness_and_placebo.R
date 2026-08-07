# 07_plot_robustness_and_placebo.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)

# ---- 图 1：稳健性热力图 ----
df1 <- read_csv(file.path(TEST_DIR, "检验结果CSV", "07_robustness.csv"), show_col_types = FALSE)
if (nrow(df1) > 0) {
  df1$variable <- factor(df1$variable, levels = c("Event_Positive", "Event_Negative", "Event_Neutral"),
                         labels = c("正向事件", "负向事件", "中性事件"))
  df1$sig_num <- ifelse(df1$pval < 0.01, 3, ifelse(df1$pval < 0.05, 2, ifelse(df1$pval < 0.10, 1, 0)))
  
  p1 <- ggplot(df1, aes(x = variable, y = test, fill = estimate)) +
    geom_tile(color = "white") +
    geom_text(aes(label = paste0(sprintf("%.3f", estimate), sig)), size = 3) +
    scale_fill_gradient2(low = "#D62728", mid = "white", high = "#2E8B57", midpoint = 0, name = "系数") +
    labs(title = "稳健性检验：不同设定下的事件效应", x = NULL, y = NULL) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "right",
          panel.grid = element_blank(),
          plot.title = element_text(face = "bold"))
  
  ggsave(file.path(OUT_DIR, "fig07_robustness_heatmap.png"), p1, width = 8, height = 6, dpi = 300)
  cat(sprintf("✓ fig07_robustness_heatmap.png 已保存\n"))
}

# ---- 图 2：安慰剂分布（简化版，仅标真实值） ----
df2 <- read_csv(file.path(TEST_DIR, "检验结果CSV", "07_placebo_tests.csv"), show_col_types = FALSE)
if (nrow(df2) > 0) {
  df2$variable <- factor(df2$variable, levels = c("Event_Positive", "Event_Negative", "Event_Neutral"),
                         labels = c("正向事件", "负向事件", "中性事件"))
  
  p2 <- ggplot(df2, aes(x = variable, y = real_estimate)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_point(size = 4, color = "#1F77B4") +
    geom_errorbar(aes(ymin = placebo_mean - 1.96 * placebo_sd,
                      ymax = placebo_mean + 1.96 * placebo_sd),
                  width = 0.2, color = "#FF7F0E", linewidth = 1) +
    geom_point(aes(y = placebo_mean), size = 3, color = "#FF7F0E", shape = 17) +
    labs(title = "安慰剂检验：真实系数 vs 安慰剂分布",
         subtitle = "蓝点为真实系数；橙色三角为安慰剂均值，误差线为 95% 区间",
         x = NULL, y = "系数") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
  
  ggsave(file.path(OUT_DIR, "fig07_placebo_distributions.png"), p2, width = 8, height = 5, dpi = 300)
  cat(sprintf("✓ fig07_placebo_distributions.png 已保存\n"))
}
