# 03_plot_seventeen_categories.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(readr)

df <- read_csv(file.path(TEST_DIR, "检验结果CSV", "03_seventeen_category_effects.csv"), show_col_types = FALSE)
df$category <- factor(df$category, levels = rev(unique(df$category)))
df$trade_label <- factor(df$trade_label, levels = c("总贸易", "出口", "进口"))

# ---- 图 1：森林图（只画总贸易） ----
df_total <- df %>% filter(trade == "Trade_Total")

p1 <- ggplot(df_total, aes(x = estimate, y = category, color = estimate > 0)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(size = 2.5) +
  geom_errorbarh(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se),
                 height = 0.2, linewidth = 0.7) +
  labs(title = "17 类事件对总贸易的影响",
       subtitle = sprintf("参照组：%s；PPML-HDFE（国家+时间固定效应，聚类到国家）", df$category[which.max(df$count)]),
       x = "系数", y = NULL,
       caption = "误差线为 95% 置信区间；* p<0.10, ** p<0.05, *** p<0.01") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none",
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold")) +
  scale_color_manual(values = c("TRUE" = "#2E8B57", "FALSE" = "#D62728"))

ggsave(file.path(OUT_DIR, "fig03_seventeen_category_forest.png"), p1, width = 8, height = 7, dpi = 300)

# ---- 图 2：热力图（三个贸易维度 × 类别，显示显著性） ----
df_heat <- df %>%
  mutate(significant = ifelse(pval < 0.10, "显著", "不显著"),
         effect = ifelse(estimate > 0, "正", "负")) %>%
  mutate(cell_label = paste0(sprintf("%.3f", estimate), sig, "\n(n=", count, ")"))

p2 <- ggplot(df_heat, aes(x = trade_label, y = category, fill = estimate)) +
  geom_tile(color = "white") +
  geom_text(aes(label = cell_label), size = 2.5, color = "black") +
  scale_fill_gradient2(low = "#D62728", mid = "white", high = "#2E8B57", midpoint = 0,
                       name = "系数") +
  labs(title = "17 类事件效应热力图",
       subtitle = "格子内为系数 + 显著性标注 + 事件次数",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "right",
        panel.grid = element_blank(),
        plot.title = element_text(face = "bold"))

ggsave(file.path(OUT_DIR, "fig03_category_heatmap.png"), p2, width = 9, height = 8, dpi = 300)

cat(sprintf("✓ fig03_seventeen_category_forest.png 已保存\n"))
cat(sprintf("✓ fig03_category_heatmap.png 已保存\n"))
