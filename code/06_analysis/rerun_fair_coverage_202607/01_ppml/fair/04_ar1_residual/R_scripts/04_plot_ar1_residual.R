# 04_plot_ar1_residual.R

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
CSV_FILE <- file.path(TEST_DIR, "检验结果CSV", "A_AR1.csv")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

dt <- fread(CSV_FILE, encoding = "UTF-8")
dt[, db := factor(db, levels = c("GDELT", "ICEWS", "Phoenix", "Tsinghua"))]

p <- ggplot(dt, aes(x = label, y = cum, fill = db)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_col(width = 0.6, color = "black", linewidth = 0.2) +
  geom_errorbar(aes(ymin = cum - 1.96 * abs(h0) / 2, ymax = cum + 1.96 * abs(h0) / 2),
                width = 0.2, color = "gray30") +
  facet_wrap(~ db, scales = "free_x", ncol = 3) +
  scale_fill_manual(values = c("GDELT" = "#D08A2E", "ICEWS" = "#006D77",
                               "Phoenix" = "#7B68EE", "Tsinghua" = "#E64B35")) +
  labs(title = "AR(1) Residual Regression: Cumulative Effects",
       subtitle = "Political shocks after removing AR(1) predictable component",
       x = "Specification", y = "Cumulative coefficient") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none", panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 14),
        axis.text.x = element_text(angle = 30, hjust = 1))

ggsave(file.path(FIG_DIR, "fig04_ar1_residual.png"), p,
       width = 10, height = 6, dpi = 300)
cat("✓ fig04_ar1_residual.png\n")
