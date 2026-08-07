# 02_plot_directional_decomp.R

rm(list = ls())

pkgs <- c("ggplot2", "dplyr", "data.table")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- dirname(normalizePath(commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))][1], winslash = "/"))
if (is.na(SCRIPT_DIR) || SCRIPT_DIR == "") SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)  # ../02_方向分解/
DB_DIR <- file.path(dirname(TEST_DIR), "01_基准传导_季度冲击", "检验结果CSV")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

f <- file.path(DB_DIR, "GDELT", "irf_all.csv")
irf <- fread(file = f, encoding = "UTF-8")
irf[, trade := factor(trade, levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                       labels = c("Total Trade", "Exports", "Imports"))]
irf_dir <- irf[grepl("-Export$|-Import$", spec)]
irf_dir[, direction := ifelse(grepl("-Export$", spec), "CHN → Partner", "Partner → CHN")]
irf_dir[, direction := factor(direction, levels = c("CHN → Partner", "Partner → CHN"))]

p <- ggplot(irf_dir, aes(x = h, y = Est, color = direction, fill = direction)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_ribbon(aes(ymin = Est - 1.96 * SE, ymax = Est + 1.96 * SE), alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2, shape = 21, color = "black", stroke = 0.3) +
  facet_wrap(~ trade, ncol = 3) +
  scale_x_continuous(breaks = 0:6, name = "Horizon (months)") +
  scale_y_continuous(name = "Coefficient") +
  scale_color_manual(values = c("CHN → Partner" = "#4DBBD5", "Partner → CHN" = "#E64B35")) +
  scale_fill_manual(values = c("CHN → Partner" = "#4DBBD5", "Partner → CHN" = "#E64B35")) +
  labs(
    title = "GDELT Directional Decomposition of Political Shocks",
    subtitle = "Effect of CHN-initiated versus Partner-initiated events on trade",
    color = "Direction",
    fill = "Direction"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 14)
  )

ggsave(file.path(FIG_DIR, "fig02_gdelt_directional_decomp.png"), p,
       width = 12, height = 5, dpi = 300)
cat("✓ fig02_gdelt_directional_decomp.png\n")
