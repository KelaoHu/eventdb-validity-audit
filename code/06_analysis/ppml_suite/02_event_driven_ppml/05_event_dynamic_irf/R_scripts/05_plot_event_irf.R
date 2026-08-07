# 05_plot_event_irf.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(readr)

VISIT_VARS <- c("V_RemoteTalk", "V_China_Outbound", "V_Partner_Inbound", "V_ThirdParty")

df <- read_csv(file.path(TEST_DIR, "检验结果CSV", "05_event_irf.csv"), show_col_types = FALSE)

# ---- 图 1：正/负/中性 IRF ----
df1 <- df %>%
  filter(type == "valence") %>%
  mutate(group = factor(group,
                        levels = c("Event_Positive", "Event_Negative", "Event_Neutral"),
                        labels = c("正向事件", "负向事件", "中性事件")))

p1 <- ggplot(df1, aes(x = horizon, y = estimate, color = group, fill = group)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(size = 2.5) +
  geom_line(linewidth = 0.8) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, color = NA) +
  facet_wrap(~ trade_label, ncol = 1) +
  scale_x_continuous(breaks = c(0, 1, 3, 6, 12)) +
  labs(title = "事件动态 IRF：正/负/中性事件对贸易的影响",
       subtitle = "PPML-HDFE（国家+时间固定效应，聚类到国家）",
       x = "事件后月份", y = "系数", color = "事件类型", fill = "事件类型") +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold"),
        strip.text = element_text(face = "bold", size = 12)) +
  scale_color_manual(values = c("正向事件" = "#2E8B57", "负向事件" = "#D62728", "中性事件" = "#7F7F7F")) +
  scale_fill_manual(values = c("正向事件" = "#2E8B57", "负向事件" = "#D62728", "中性事件" = "#7F7F7F"))

ggsave(file.path(OUT_DIR, "fig05_irf_positive_negative.png"), p1, width = 9, height = 8, dpi = 300)

# ---- 图 2：4 类访问 IRF ----
df2 <- df %>%
  filter(type == "visit") %>%
  mutate(group = factor(group,
                        levels = c("V_RemoteTalk", "V_China_Outbound", "V_Partner_Inbound", "V_ThirdParty"),
                        labels = c("远程通话", "中方领导人出访", "外方领导人来访",
                                   "第三方会晤")))

p2 <- ggplot(df2, aes(x = horizon, y = estimate, color = group)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(size = 2) +
  geom_line(linewidth = 0.7) +
  scale_x_continuous(breaks = c(0, 1, 3, 6, 12)) +
  labs(title = "4 类领导人访问/会晤的动态 IRF",
       subtitle = "仅总贸易；PPML-HDFE（国家+时间固定效应，聚类到国家）",
       x = "事件后月份", y = "系数", color = "访问类型") +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold")) +
  scale_color_brewer(palette = "Set1")

ggsave(file.path(OUT_DIR, "fig05_irf_four_visits.png"), p2, width = 10, height = 6, dpi = 300)

cat(sprintf("✓ fig05_irf_positive_negative.png 已保存\n"))
cat(sprintf("✓ fig05_irf_four_visits.png 已保存\n"))
