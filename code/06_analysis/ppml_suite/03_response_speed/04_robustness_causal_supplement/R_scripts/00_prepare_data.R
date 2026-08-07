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
TEST_DIR <- dirname(SCRIPT_DIR)           # ../04_稳健性与因果识别补充/
PPML_DIR <- dirname(dirname(TEST_DIR))    # ../新PPMLHDFE/
OUT_DIR <- file.path(TEST_DIR, "中间数据")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/4] 读取经济面板与四库政治分数（z-score + AR(1) 冲击）...\n")
source(file.path(PPML_DIR, "01_连续分数PPML", "00_utils.R"), encoding = "UTF-8")

panel <- load_panel(PPML_DIR)
scores <- load_scores(PPML_DIR)
# prepare_panel_db 已生成 PolZ、u（AR1 残差）、u_L1..L6，以及 Tsinghua 差分
panel_db <- prepare_panel_db(panel, scores)

# 保留关键变量
keep_vars <- c("ISO", "Country", "YearMonth", "month", "db",
               "Trade_Exports", "Trade_Imports", "Trade_Total",
               "ln_GDP", "ln_GDP_product", "ln_ER", "FTA_Dummy",
               "Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN",
               "PolZ_Agg", "PolZ_CHN_Partner", "PolZ_Partner_CHN",
               "u_Agg", "u_CHN_Partner", "u_Partner_CHN",
               "dPol_Agg")
panel_db <- panel_db[, ..keep_vars]
panel_db[, YearMonth := as.Date(YearMonth)]

cat("[2/4] 读取事件面板...\n")
event_panel <- fread(file = file.path(PPML_DIR, "02_事件驱动PPMLHDFE", "00_事件面板构建", "中间数据", "event_panel_ready.csv"),
                     encoding = "UTF-8")
setnames(event_panel, sub("^\ufeff", "", names(event_panel)))
event_panel[, YearMonth := as.Date(YearMonth)]

# 选取需要的事件相关变量
event_cols <- c("ISO", "YearMonth",
                "Event_Positive", "Event_Negative", "Event_Neutral", "Event_Count",
                "V_RemoteTalk", "V_China_Outbound", "V_Partner_Inbound", "V_ThirdParty",
                "Cat_高层互访", "Cat_经贸互利合作", "Cat_经贸制裁/关税壁垒",
                "Cat_科技管制/出口限制", "Cat_战略伙伴关系提升", "Cat_战略定位负面",
                "Cat_外交抗议/摩擦", "Cat_安全威胁")
event_cols <- intersect(event_cols, names(event_panel))
event_dt <- event_panel[, ..event_cols]

# 将事件变量合并到每个 db 的分数行（all.y 保留所有 db-国家-月份）
panel_full <- merge(panel_db, event_dt, by = c("ISO", "YearMonth"), all.y = FALSE)
# all.y=FALSE 保留 panel_db 所有行，事件缺失填 NA

cat("[3/4] 生成 FTA 生效虚拟变量...\n")
fta_date <- panel_full[FTA_Dummy == 1, .(fta_date = min(YearMonth, na.rm = TRUE)), by = ISO]
all_iso <- data.table(ISO = unique(panel_full$ISO))
fta_date <- merge(all_iso, fta_date, by = "ISO", all.x = TRUE)
panel_full <- merge(panel_full, fta_date, by = "ISO", all.x = TRUE)
panel_full[, Post_FTA := ifelse(!is.na(fta_date) & YearMonth >= fta_date, 1L, 0L)]
panel_full[, Has_FTA := as.integer(any(FTA_Dummy == 1, na.rm = TRUE)), by = ISO]

cat("[4/4] 保存统一数据集...\n")
fwrite(panel_full, file.path(OUT_DIR, "panel_for_robustness.csv"))
cat(sprintf("✓ panel_for_robustness.csv 已保存 (%d 行)\n", nrow(panel_full)))
print(panel_full[, .(n = .N, n_iso = uniqueN(ISO)), by = db])
