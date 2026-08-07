# 02_plot_valence_and_visits.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(readr)

# ---- 图 1：正负向非对称 ----
df1 <- read_csv(file.path(TEST_DIR, "检验结果CSV", "02_valence_asymmetry.csv"), show_col_types = FALSE)
df1_main <- df1 %>% filter(variable != "Wald_Pos_Equals_Neg")
df1_main$variable <- factor(df1_main$variable, levels = c("Event_Positive", "Event_Negative"),
                            labels = c("正向事件", "负向事件"))
df1_main$trade_label <- factor(df1_main$trade_label, levels = c("总贸易", "出口", "进口"))

p1 <- ggplot(df1_main, aes(x = estimate, y = variable, color = variable)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se),
                 height = 0.2, linewidth = 0.8) +
  facet_wrap(~ trade_label, ncol = 1) +
  labs(title = "正负向事件对贸易的非对称影响",
       subtitle = "PPML-HDFE（国家+时间固定效应，聚类到国家）",
       x = "系数", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none",
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold")) +
  scale_color_manual(values = c("正向事件" = "#2E8B57", "负向事件" = "#D62728"))

ggsave(file.path(OUT_DIR, "fig02_valence_asymmetry.png"), p1, width = 8, height = 5, dpi = 300)

# ---- 图 2：4 类访问效应 ----
df2 <- read_csv(file.path(TEST_DIR, "检验结果CSV", "02_four_visit_effects.csv"), show_col_types = FALSE)
df2$variable <- factor(df2$variable,
                       levels = c("远程通话", "中方领导人出访", "外方领导人来访",
                                  "第三方会晤"),
                       labels = c("远程通话", "中方领导人出访", "外方领导人来访",
                                  "第三方会晤"))
df2$trade_label <- factor(df2$trade_label, levels = c("总贸易", "出口", "进口"))

p2 <- ggplot(df2, aes(x = estimate, y = variable)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(size = 3, color = "#1F77B4") +
  geom_errorbarh(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se),
                 height = 0.2, linewidth = 0.8, color = "#1F77B4") +
  facet_wrap(~ trade_label, ncol = 1) +
  labs(title = "4 类领导人访问/会晤事件对贸易的影响",
       subtitle = "以第三方会晤为参照组；PPML-HDFE（国家+时间固定效应，聚类到国家）",
       x = "系数", y = NULL,
       caption = "误差线为 95% 置信区间；* p<0.10, ** p<0.05, *** p<0.01") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none",
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold"),
        strip.text = element_text(face = "bold", size = 12))

ggsave(file.path(OUT_DIR, "fig02_four_visit_effects.png"), p2, width = 8, height = 6, dpi = 300)

cat(sprintf("✓ fig02_valence_asymmetry.png 已保存\n"))
cat(sprintf("✓ fig02_four_visit_effects.png 已保存\n"))
