# 05_plot_freq_scan.R

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
CSV_FILE <- file.path(TEST_DIR, "检验结果CSV", "B_freqscan.csv")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

dt <- fread(CSV_FILE, encoding = "UTF-8")
dt[, db := factor(db, levels = c("GDELT", "ICEWS", "Phoenix", "Tsinghua"))]

p <- ggplot(dt, aes(x = k, y = cum, color = db, group = db)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  scale_color_manual(values = c("GDELT" = "#D08A2E", "ICEWS" = "#006D77",
                                "Phoenix" = "#7B68EE", "Tsinghua" = "#E64B35")) +
  scale_x_continuous(breaks = unique(dt$k)) +
  labs(title = "Frequency Response Scan: Cumulative Effect by Window Length",
       subtitle = "Cumulative political shock over k months on total trade",
       x = "Window length k (months)", y = "Cumulative coefficient", color = "Database") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 14))

ggsave(file.path(FIG_DIR, "fig05_freq_scan.png"), p,
       width = 9, height = 6, dpi = 300)
cat("✓ fig05_freq_scan.png\n")
