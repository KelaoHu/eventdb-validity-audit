# 09g_plot_mechanism_and_robustness.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
OUT_PNG <- file.path(TEST_DIR, "图片", "fig09b_mechanism_and_robustness.png")

library(ggplot2)
library(dplyr)
library(readr)
library(patchwork)

# ---- 机制 ----
mech <- read_csv(file.path(TEST_DIR, "检验结果CSV", "09b_mechanism_economic_cooperation.csv"), show_col_types = FALSE)
mech_pre <- mech %>% filter(test == "pre_trend_lead") %>%
  mutate(horizon = as.integer(gsub(".*_F", "", variable)),
         horizon_label = paste0("t-", horizon))

p1 <- ggplot(mech_pre, aes(x = horizon, y = estimate, color = trade_label)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se), width = 0.2) +
  scale_x_reverse(breaks = 1:3, labels = c("t-1", "t-2", "t-3")) +
  labs(title = "经贸互利合作：事前趋势", x = "事件前月份", y = "系数", color = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

# ---- 稳健性 ----
rob <- read_csv(file.path(TEST_DIR, "检验结果CSV", "09c_robustness_economic_cooperation.csv"), show_col_types = FALSE)
rob_plot <- rob %>% filter(test != "leave_one_event_out_summary") %>%
  mutate(test = factor(test, levels = rev(unique(test))),
         sig = ifelse(pvalue < 0.10, "显著", "不显著"))

p2 <- ggplot(rob_plot, aes(x = estimate, y = test, color = sig)) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_point(position = position_dodge(width = 0.5)) +
  geom_errorbarh(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se), height = 0.2,
                 position = position_dodge(width = 0.5)) +
  facet_wrap(~ trade_label, scales = "free_x") +
  scale_color_manual(values = c("显著" = "#d62728", "不显著" = "#1f77b4")) +
  labs(title = "经贸互利合作：稳健性设定", x = "系数", y = NULL, color = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

p <- p1 / p2 + plot_annotation(title = "经贸互利合作负系数：机制解释与稳健性")
ggsave(OUT_PNG, p, width = 12, height = 10, dpi = 300)
cat(sprintf("✓ %s 已保存\n", OUT_PNG))
