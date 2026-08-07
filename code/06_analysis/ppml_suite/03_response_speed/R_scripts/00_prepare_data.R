# 00_prepare_data.R

rm(list = ls())

pkgs <- c("fixest", "data.table", "dplyr", "readr", "tidyr", "ggplot2", "stringr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)           # ../03_响应速度复现/
PPML_DIR <- dirname(TEST_DIR)             # ../新PPMLHDFE/
DATA_DIR <- file.path(PPML_DIR, "data")
SCORE_DIR <- file.path(PPML_DIR, "..", "..", "3.2 双边关系分析基于月度政治分数", "全新事件研究法", "data")
SCORE_DIR <- normalizePath(SCORE_DIR, winslash = "/")
OUT_DIR <- file.path(TEST_DIR, "中间数据")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/4] 读取经济面板...\n")
panel <- fread(file = file.path(DATA_DIR, "panel_clean.csv"), encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, month := as.Date(month)]
panel[, YearMonth := month]
panel[, Country := as.character(Country)]
panel[, ISO := as.character(ISO)]

cat("[2/4] 读取四库政治分数...\n")

read_score_long <- function(csv, db_name) {
  dt <- fread(file = csv, encoding = "UTF-8")
  setnames(dt, sub("^\ufeff", "", names(dt)))
  dt[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
  dt <- dcast(dt, Partner + YearMonth ~ Index_Type, value.var = "Index_Value")
  setnames(dt, c("Aggregated", "CHN->Partner", "Partner->CHN"),
           c("Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"), skip_absent = TRUE)
  dt[, db := db_name]
  dt[, Country := Partner]
  return(dt[, !"Partner"])
}

gdelt <- read_score_long(file.path(SCORE_DIR, "gdelt_scores.csv"), "GDELT")
icews <- read_score_long(file.path(SCORE_DIR, "icews_scores.csv"), "ICEWS")
phoenix <- read_score_long(file.path(SCORE_DIR, "phoenix_scores.csv"), "Phoenix")

tsinghua <- fread(file = file.path(SCORE_DIR, "tsinghua_scores.csv"), encoding = "UTF-8")
setnames(tsinghua, sub("^\ufeff", "", names(tsinghua)))
tsinghua[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
setnames(tsinghua, c("Country", "YearMonth", "Score"), c("Country", "YearMonth", "Pol_Agg"))
tsinghua[, db := "Tsinghua"]

scores <- rbindlist(list(gdelt, icews, phoenix, tsinghua), fill = TRUE, use.names = TRUE)

cat("[3/4] 合并面板与政治分数，生成分布滞后 L0-L6...\n")

panel_db <- merge(panel, scores, by = c("Country", "YearMonth"), all.x = TRUE)
setorder(panel_db, db, ISO, YearMonth)

# 生成分布滞后变量
POL_VARS <- c("Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN")
HORIZONS <- 0:6

for (pol in POL_VARS) {
  if (!pol %in% names(panel_db)) next
  # L0
  panel_db[, (paste0(pol, "_L0")) := get(pol)]
  # L1-L6
  for (h in 1:6) {
    panel_db[, (paste0(pol, "_L", h)) := shift(get(pol), n = h, type = "lag"), by = .(db, ISO)]
  }
}

# 删除没有分数的 db-ISO 行（减少文件大小）
panel_db <- panel_db[!is.na(db)]

fwrite(panel_db, file.path(OUT_DIR, "panel_with_scores_and_lags.csv"))
cat(sprintf("✓ 中间数据已保存：panel_with_scores_and_lags.csv (%d 行)\n", nrow(panel_db)))

cat("[4/4] 定义滚动窗口...\n")

# 窗口长度 60 个月，步进 12 个月
WINDOW_MONTHS <- 60
STEP_MONTHS <- 12

start_dates <- seq(as.Date("2002-01-01"), as.Date("2021-01-01"), by = "12 months")
window_end <- as.Date(sapply(start_dates, function(s) seq(s, length = 2, by = paste(WINDOW_MONTHS, "months"))[2] - 1))
window_midpoint <- as.Date(sapply(start_dates, function(s) seq(s, length = 2, by = paste(WINDOW_MONTHS / 2, "months"))[2]))

windows <- data.table(
  window_id = seq_along(start_dates),
  window_start = start_dates,
  window_end = window_end
)
windows[, window_midpoint := window_midpoint]
windows[, window_label := format(window_midpoint, "%Y")]

fwrite(windows, file.path(OUT_DIR, "windows.csv"))
cat(sprintf("✓ 滚动窗口已保存：windows.csv (%d 个窗口)\n", nrow(windows)))
print(windows)
