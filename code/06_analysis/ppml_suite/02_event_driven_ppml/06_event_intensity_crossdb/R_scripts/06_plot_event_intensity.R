# 06_plot_event_intensity.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(readr)

# ---- 图 1：四库交叉验证 ----
df1 <- read_csv(file.path(TEST_DIR, "检验结果CSV", "06_cross_db_validation.csv"), show_col_types = FALSE)
if (nrow(df1) > 0) {
  df1$db <- factor(df1$db, levels = c("GDELT", "ICEWS", "Phoenix", "Tsinghua"))
  df1$trade_label <- factor(df1$trade_label, levels = c("总贸易", "出口", "进口"))
  
  p1 <- ggplot(df1, aes(x = db, y = estimate, color = db)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se), width = 0.2, linewidth = 0.8) +
    facet_wrap(~ trade_label, ncol = 1) +
    labs(title = "四库事件强度对贸易的影响",
         subtitle = "系数为事件前后政治分数 z-score 变化的边际效应；PPML-HDFE",
         x = "数据库", y = "系数", color = "数据库") +
    theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(face = "bold"),
          strip.text = element_text(face = "bold", size = 12),
          axis.text.x = element_text(angle = 30, hjust = 1)) +
    scale_color_manual(values = c("GDELT" = "#D4A017", "ICEWS" = "#007C7C",
                                  "Phoenix" = "#CC5500", "Tsinghua" = "#5B7B8D"))
  
  ggsave(file.path(OUT_DIR, "fig06_cross_db_comparison.png"), p1, width = 8, height = 7, dpi = 300)
  cat(sprintf("✓ fig06_cross_db_comparison.png 已保存\n"))
}

# ---- 图 2：剂量反应 ----
df2 <- read_csv(file.path(TEST_DIR, "检验结果CSV", "06_dose_response.csv"), show_col_types = FALSE)
if (nrow(df2) > 0) {
  df2$db <- factor(df2$db, levels = c("GDELT", "ICEWS", "Phoenix", "Tsinghua"))
  df2$trade_label <- factor(df2$trade_label, levels = c("总贸易", "出口", "进口"))
  
  p2 <- ggplot(df2, aes(x = dose, y = estimate, color = db, group = db)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_point(size = 2.5, position = position_dodge(width = 0.3)) +
    geom_errorbar(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se),
                  width = 0.2, linewidth = 0.7, position = position_dodge(width = 0.3)) +
    geom_line(position = position_dodge(width = 0.3), linewidth = 0.6) +
    facet_wrap(~ trade_label, ncol = 1) +
    labs(title = "事件强度剂量反应（低/中/高三分位）",
         subtitle = "以低强度事件为参照组；PPML-HDFE",
         x = "强度分位", y = "系数", color = "数据库") +
    theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(face = "bold"),
          strip.text = element_text(face = "bold", size = 12)) +
    scale_color_manual(values = c("GDELT" = "#D4A017", "ICEWS" = "#007C7C",
                                  "Phoenix" = "#CC5500", "Tsinghua" = "#5B7B8D"))
  
  ggsave(file.path(OUT_DIR, "fig06_dose_response.png"), p2, width = 9, height = 7, dpi = 300)
  cat(sprintf("✓ fig06_dose_response.png 已保存\n"))
}
