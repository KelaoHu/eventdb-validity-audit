# 09f_plot_reliability.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_CSV <- file.path(TEST_DIR, "检验结果CSV", "09a_reliability_category_effects.csv")
OUT_PNG <- file.path(TEST_DIR, "图片", "fig09a_fdr_adjusted_forest.png")

library(ggplot2)
library(dplyr)
library(readr)

df <- read_csv(OUT_CSV, show_col_types = FALSE)

# 剔除被回归自动剔除的类别（共线性/无变异）
df <- df %>% filter(is.na(dropped) | dropped == 0)

# 标记关键类别与显著性
df$key <- ifelse(df$category %in% c("人文交流合作", "战略定位负面", "经贸互利合作"), "关键类别", "其他")
df$sig <- ifelse(!is.na(df$qvalue_bh_by_trade) & df$qvalue_bh_by_trade < 0.10, "FDR 显著", "不显著")
df$label <- paste0(df$trade_label, "：", df$category)

p <- ggplot(df, aes(x = estimate, y = reorder(label, estimate), color = key, alpha = sig)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(aes(size = count), position = position_dodge(width = 0.5)) +
  geom_errorbarh(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se), height = 0.2) +
  scale_color_manual(values = c("关键类别" = "#d62728", "其他" = "#1f77b4")) +
  scale_alpha_manual(values = c("FDR 显著" = 1, "不显著" = 0.5)) +
  labs(
    title = "17 类事件效应（FDR 校正后）",
    subtitle = "以高层互访为参照；仅显示未被回归剔除的类别；点大小为事件频数",
    x = "系数（贸易变化百分比）",
    y = NULL,
    color = NULL,
    alpha = NULL,
    size = "事件数"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(OUT_PNG, p, width = 10, height = 8, dpi = 300)
cat(sprintf("✓ %s 已保存\n", OUT_PNG))
