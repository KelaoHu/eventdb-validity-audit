# 01_plot_irf_aggregate.R

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
TEST_DIR <- dirname(SCRIPT_DIR)  # ../01_基准传导_季度冲击/
DB_DIR <- file.path(TEST_DIR, "检验结果CSV")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
irf_all <- lapply(DBS, function(db) {
  f <- file.path(DB_DIR, db, "irf_all.csv")
  if (!file.exists(f)) return(NULL)
  dt <- fread(file = f, encoding = "UTF-8")
  dt[, db := db]
  dt
})
irf <- rbindlist(irf_all, use.names = TRUE)
irf[, db := factor(db, levels = DBS)]
irf[, trade := factor(trade, levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                       labels = c("Total Trade", "Exports", "Imports"))]

irf_total <- irf[grepl("-Total$", spec)]

p <- ggplot(irf_total, aes(x = h, y = Est, color = db, fill = db)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_ribbon(aes(ymin = Est - 1.96 * SE, ymax = Est + 1.96 * SE), alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2, shape = 21, color = "black", stroke = 0.3) +
  facet_wrap(~ trade, ncol = 3) +
  scale_x_continuous(breaks = 0:6, name = "Horizon (months)") +
  scale_y_continuous(name = "Coefficient") +
  scale_color_manual(values = c("GDELT" = "#D08A2E", "ICEWS" = "#006D77",
                                "Phoenix" = "#7B68EE", "Tsinghua" = "#E64B35")) +
  scale_fill_manual(values = c("GDELT" = "#D08A2E", "ICEWS" = "#006D77",
                               "Phoenix" = "#7B68EE", "Tsinghua" = "#E64B35")) +
  labs(
    title = "Impulse Responses of Aggregate Political Shocks on Trade",
    subtitle = "PPML-HDFE with country and month fixed effects; clustered SE by country",
    color = "Database",
    fill = "Database"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 14)
  )

ggsave(file.path(FIG_DIR, "fig01_irf_aggregate_four_databases.png"), p,
       width = 12, height = 5, dpi = 300)
cat("✓ fig01_irf_aggregate_four_databases.png\n")
