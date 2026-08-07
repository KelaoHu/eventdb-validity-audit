# 绘制干净面板 PPML 累计效应图

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
CSV_FILE <- file.path(TEST_DIR, "检验结果CSV", "ppml_final.csv")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

dt <- fread(CSV_FILE, encoding = "UTF-8")
dt[, db := sub("_.*$", "", label)]
dt[, variant := sub("^[A-Z]+_", "", label)]
dt[, variant := sub("-.*$", "", variant)]
dt[, trade := sub("^.*-", "", label)]

dt[, db := factor(db, levels = c("GD", "IW", "PH", "TS"),
                  labels = c("GDELT", "ICEWS", "Phoenix", "Tsinghua"))]
dt[, trade := factor(trade, levels = c("Total", "Exports", "Imports"))]

# 只画 aggregate 变体（- 和 abs）
dt_plot <- dt[variant %in% c("-", "abs")]

cols <- c("-" = "#4DBBD5", "abs" = "#E64B35")
p <- ggplot(dt_plot, aes(x = trade, y = cum, fill = variant)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_col(position = position_dodge(width = 0.7), width = 0.6, color = "black", linewidth = 0.2) +
  facet_wrap(~ db, ncol = 2) +
  scale_fill_manual(values = cols, labels = c("-" = "signed", "abs" = "absolute")) +
  labs(title = "Clean Panel PPML: Cumulative Effect of Political Score on Trade",
       subtitle = "Joint distributed lag model (h = 0..6)",
       x = "Trade flow", y = "Cumulative coefficient", fill = "Score type") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 14))

ggsave(file.path(FIG_DIR, "fig03_clean_panel_ppml.png"), p,
       width = 10, height = 7, dpi = 300)
cat("✓ fig03_clean_panel_ppml.png\n")
