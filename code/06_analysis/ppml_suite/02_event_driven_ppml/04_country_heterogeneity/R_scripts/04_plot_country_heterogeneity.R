# 04_plot_country_heterogeneity.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)

df <- read_csv(file.path(TEST_DIR, "检验结果CSV", "04_country_heterogeneity.csv"), show_col_types = FALSE)
if (nrow(df) == 0) {
  cat("没有国家异质性结果可绘图\n")
  quit(status = 0)
}

# 敏感度排名
sens <- df %>%
  distinct(ISO, Country, sensitivity) %>%
  arrange(desc(sensitivity)) %>%
  mutate(Country = factor(Country, levels = Country))

p1 <- ggplot(sens, aes(x = sensitivity, y = Country, fill = sensitivity > 0)) +
  geom_col() +
  labs(title = "国家对政治事件的贸易敏感度排名",
       subtitle = "敏感度 = 负向事件系数 − 正向事件系数（仅总贸易）",
       x = "敏感度指数", y = NULL) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none",
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold")) +
  scale_fill_manual(values = c("TRUE" = "#D62728", "FALSE" = "#2E8B57"))

ggsave(file.path(OUT_DIR, "fig04_country_sensitivity_ranking.png"), p1, width = 8, height = 8, dpi = 300)

# 散点图：正向 vs 负向（仅总贸易）
df_wide <- df %>%
  filter(trade == "Trade_Total") %>%
  select(ISO, Country, variable, estimate) %>%
  pivot_wider(names_from = variable, values_from = estimate)

p2 <- ggplot(df_wide, aes(x = Event_Positive, y = Event_Negative, label = Country)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(size = 3, color = "#1F77B4") +
  geom_text(vjust = -0.8, size = 3) +
  labs(title = "各国正向 vs 负向事件对总贸易的影响",
       x = "正向事件系数", y = "负向事件系数") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(OUT_DIR, "fig04_country_pos_neg_scatter.png"), p2, width = 8, height = 7, dpi = 300)

cat(sprintf("✓ fig04_country_sensitivity_ranking.png 已保存\n"))
cat(sprintf("✓ fig04_country_pos_neg_scatter.png 已保存\n"))
