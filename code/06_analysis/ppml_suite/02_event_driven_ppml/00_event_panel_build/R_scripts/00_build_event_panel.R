# 构建 02_事件驱动PPMLHDFE 主数据集

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)           # ../00_事件面板构建/
PPML_DIR <- dirname(TEST_DIR)             # ../02_事件驱动PPMLHDFE/
ROOT_DIR <- dirname(PPML_DIR)             # 新PPMLHDFE 根目录
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "中间数据")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/4] 读取经济面板...\n")
panel <- load_panel(ROOT_DIR)
cat(sprintf("  面板: %d 行, %d 国家\n", nrow(panel), uniqueN(panel$ISO)))

cat("[2/4] 读取 713 事件库...\n")
events <- load_events(ROOT_DIR)
cat(sprintf("  事件: %d 条\n", nrow(events)))
cat("  impact 分布:\n")
print(events[, .N, by = impact][order(-N)])
cat("  17 类事件分布:\n")
print(events[, .N, by = event_category][order(-N)])

cat("[3/4] 读取四库分数...\n")
scores <- load_scores(ROOT_DIR)
cat(sprintf("  分数: %d 行, %d 库\n", nrow(scores), uniqueN(scores$db)))

cat("[4/4] 构建事件面板...\n")
panel_ev <- build_event_panel(panel, events, scores)

# 生成事件滞后变量（用于后续 IRF）
event_vars <- c("Event_Positive", "Event_Negative", "Event_Neutral", VISIT_VARS)
# 找出 17 类变量
cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
event_vars <- c(event_vars, cat_cols)
panel_ev <- make_event_lags(panel_ev, event_vars, horizons = c(1, 3, 6, 12))

# 生成事件摘要
summary_by_category <- events[, .(
  n = .N,
  n_positive = sum(impact == "positive", na.rm = TRUE),
  n_negative = sum(impact == "negative", na.rm = TRUE),
  n_neutral = sum(impact == "neutral", na.rm = TRUE)
), by = .(event_category, event_category_en)][order(-n)]

# 保存
fwrite(panel_ev, file.path(OUT_DIR, "event_panel_ready.csv"))
fwrite(summary_by_category, file.path(OUT_DIR, "event_summary_by_category.csv"))

cat(sprintf("\n✓ event_panel_ready.csv 已保存: %d 行, %d 列\n", nrow(panel_ev), ncol(panel_ev)))
cat(sprintf("✓ event_summary_by_category.csv 已保存: %d 行\n", nrow(summary_by_category)))
