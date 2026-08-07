# 03_plot_scaling.R

rm(list = ls())

pkgs <- c("ggplot2", "data.table")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- dirname(normalizePath(commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))][1], winslash = "/"))
if (is.na(SCRIPT_DIR) || SCRIPT_DIR == "") SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)  # ../C_信噪比效应量标度律/
SCALING_FILE <- file.path(TEST_DIR, "检验结果CSV", "C_scaling.csv")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(SCALING_FILE)) {
  stop("找不到 scaling 文件：", SCALING_FILE)
}

scaling <- fread(file = SCALING_FILE, encoding = "UTF-8")
DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
scaling[, db := factor(db, levels = DBS)]

p <- ggplot(scaling, aes(x = db, y = rho, fill = db)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 0, color = "black") +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  scale_fill_manual(values = c("GDELT" = "#D08A2E", "ICEWS" = "#006D77",
                               "Phoenix" = "#7B68EE", "Tsinghua" = "#E64B35")) +
  labs(
    title = "AR(1) Persistence of Political Score (after pre-processing)",
    subtitle = "Tsinghua uses first-differenced score; red line = unit root boundary",
    x = "Database",
    y = expression(rho)
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none", plot.title = element_text(face = "bold", size = 14))

ggsave(file.path(FIG_DIR, "fig03_ar1_rho_comparison.png"), p,
       width = 8, height = 5, dpi = 300)
cat("✓ fig03_ar1_rho_comparison.png\n")
