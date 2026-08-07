# 09i_plot_subsample.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_PNG <- file.path(TEST_DIR, "图片", "fig09d_subsample_heatmap.png")

library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)

df <- read_csv(file.path(TEST_DIR, "检验结果CSV", "09e_subsample_heterogeneity.csv"), show_col_types = FALSE)

# 仅保留 Wald 检验为显著的交互以及分样本系数
df_plot <- df %>%
  filter(dimension != "full_sample" | group == "all") %>%
  filter(!is.na(estimate)) %>%
  mutate(sig = ifelse(pvalue < 0.10, "*", ""),
         label = sprintf("%.3f%s", estimate, sig),
         panel = paste0(category, " → ", trade_label))

p <- ggplot(df_plot, aes(x = group, y = dimension, fill = estimate)) +
  geom_tile(color = "white") +
  geom_text(aes(label = label), size = 3) +
  facet_wrap(~ panel, scales = "free", ncol = 3) +
  scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b", midpoint = 0) +
  labs(
    title = "关键类别效应的分样本异质性",
    subtitle = "* 表示 p<0.10；Wald 检验显著的维度已在数据中标记",
    x = NULL,
    y = NULL,
    fill = "系数"
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")

ggsave(OUT_PNG, p, width = 14, height = 10, dpi = 300)
cat(sprintf("✓ %s 已保存\n", OUT_PNG))
