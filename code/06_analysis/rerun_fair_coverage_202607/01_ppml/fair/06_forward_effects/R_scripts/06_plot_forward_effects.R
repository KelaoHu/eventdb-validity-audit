# 06_plot_forward_effects.R

rm(list = ls())

pkgs <- c("ggplot2", "data.table")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
CSV_FILE <- file.path(TEST_DIR, "检验结果CSV", "D_forward.csv")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

dt <- fread(CSV_FILE, encoding = "UTF-8")
dt[, sig := ifelse(pv < 0.05, "p < 0.05", "p >= 0.05")]

p <- ggplot(dt, aes(x = h, y = Est)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_vline(xintercept = 0, linetype = "dotted", color = "gray60") +
  geom_ribbon(aes(ymin = Est - 1.96 * SE, ymax = Est + 1.96 * SE), alpha = 0.2, fill = "#4DBBD5") +
  geom_line(color = "#006D77", linewidth = 1) +
  geom_point(aes(color = sig), size = 3) +
  scale_color_manual(values = c("p < 0.05" = "#E64B35", "p >= 0.05" = "#4DBBD5")) +
  scale_x_continuous(breaks = dt$h, name = "Horizon h (months)") +
  labs(title = "Forward Effects: Political Shock and Trade Over Time",
       subtitle = "Negative h = lead (future shock); positive h = lag (past shock)",
       y = "Coefficient", color = "Significance") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 14))

ggsave(file.path(FIG_DIR, "fig06_forward_effects.png"), p,
       width = 9, height = 6, dpi = 300)
cat("✓ fig06_forward_effects.png\n")
