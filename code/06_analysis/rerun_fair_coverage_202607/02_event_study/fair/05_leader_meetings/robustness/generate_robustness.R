# M5 Robustness: 4-category leader meeting effect

library(tidyverse)

IN_CSV <- "../code/results/leader_meeting_effects.csv"
OUT_PNG <- "m5_robustness_category4.png"
OUT_CSV <- "m5_robustness_category4.csv"

df <- read_csv(IN_CSV, show_col_types = FALSE, locale = locale(encoding = "UTF-8"))

summary_df <- df %>%
  filter(post_month == 0) %>%
  group_by(db, category_4) %>%
  summarise(
    mean = mean(shock, na.rm = TRUE),
    sd = sd(shock, na.rm = TRUE),
    n = n(),
    se = sd / sqrt(n),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  ) %>%
  mutate(
    category_4 = factor(
      category_4,
      levels = c(
        "Chinese outbound visit",
        "Partner inbound visit",
        "Third-party meeting",
        "Remote talk"
      )
    ),
    db = factor(db, levels = c("GDELT", "ICEWS"))
  )

write_csv(summary_df, OUT_CSV)

p <- ggplot(summary_df, aes(x = category_4, y = mean, fill = category_4)) +
  geom_bar(stat = "identity", color = "white", width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2, linewidth = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  facet_wrap(~ db, ncol = 2) +
  scale_fill_manual(values = c(
    "Chinese outbound visit" = "#D62728",
    "Partner inbound visit" = "#1F77B4",
    "Third-party meeting" = "#2CA02C",
    "Remote talk" = "#FF6FFF"
  )) +
  labs(
    title = "M5 Robustness: Leader Meeting Effect by 4 Categories",
    subtitle = "Post-month = 0 | Shock = Goldstein score change vs. 3-month pre-event baseline",
    x = NULL,
    y = "Immediate index score change",
    fill = "Meeting type"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 20, hjust = 1),
    legend.position = "bottom",
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 12)
  )

ggsave(OUT_PNG, p, width = 10, height = 6, dpi = 300, bg = "white")
cat("[DONE]", OUT_PNG, "\n")
print(summary_df)
