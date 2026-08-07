# 02_generate_directional_csv.R

rm(list = ls())

pkgs <- c("data.table")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
IRF_FILE <- file.path(TEST_DIR, "..", "01_基准传导_季度冲击", "检验结果CSV", "GDELT", "irf_all.csv")
OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

irf <- fread(IRF_FILE, encoding = "UTF-8")
irf_dir <- irf[grepl("-Export$|-Import$", spec)]
irf_dir[, direction := ifelse(grepl("-Export$", spec), "CHN -> Partner", "Partner -> CHN")]
irf_dir[, direction := factor(direction, levels = c("CHN -> Partner", "Partner -> CHN"))]
irf_dir[, trade := factor(trade, levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                          labels = c("Total", "Exports", "Imports"))]

out <- irf_dir[, .(db, spec, direction, trade, h, Est, SE, pv, cum, n)]
setorder(out, direction, trade, h)

fwrite(out, file.path(OUT_DIR, "directional_decomp.csv"))
cat("✓ directional_decomp.csv saved (", nrow(out), "rows)\n")
