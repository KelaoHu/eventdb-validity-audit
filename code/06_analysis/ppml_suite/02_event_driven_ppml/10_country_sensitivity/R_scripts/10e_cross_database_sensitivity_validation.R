# 10e_cross_database_sensitivity_validation.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "检验结果CSV")
FIG_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/3] 读取事件敏感度（10b）与四库政治分数...\n")

# 事件驱动敏感度
sens_dt <- fread(file.path(OUT_DIR, "10b_country_sensitivity_for_meta.csv"), encoding = "UTF-8")
setnames(sens_dt, sub("^\ufeff", "", names(sens_dt)))

# 四库分数路径
SCORE_DIR <- file.path(ROOT_DIR, "..", "..", "3.2 双边关系分析基于月度政治分数", "全新事件研究法", "data")
SCORE_DIR <- normalizePath(SCORE_DIR, winslash = "/")

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

# 国家名映射：分数用 Country 全名，敏感度用 ISO
panel_ref <- fread(file.path(ROOT_DIR, "data", "panel_clean.csv"), encoding = "UTF-8")
setnames(panel_ref, sub("^\ufeff", "", names(panel_ref)))
iso_map <- unique(panel_ref[, .(ISO, Country)])
scores <- merge(scores, iso_map, by = "Country", all.x = TRUE)

# ----------------------------------------------------------------------------
# 2) 计算各国政治分数波动率
# ----------------------------------------------------------------------------
cat("[2/3] 计算各国政治分数波动率...\n")

volatility <- scores[!is.na(Pol_Agg), .(
  sd_score = sd(Pol_Agg, na.rm = TRUE),
  sd_zscore = sd(scale(Pol_Agg)[, 1], na.rm = TRUE),
  n = sum(!is.na(Pol_Agg))
), by = .(db, ISO)]

vol_wide <- dcast(volatility, ISO ~ db, value.var = "sd_score")
setnames(vol_wide, names(vol_wide)[-1], paste0("vol_", names(vol_wide)[-1]))

# 合并到敏感度
cross_dt <- merge(sens_dt, vol_wide, by = "ISO", all.x = TRUE)

fwrite(cross_dt, file.path(OUT_DIR, "10e_cross_db_data.csv"))
cat(sprintf("✓ 10e_cross_db_data.csv 已保存 (%d 行)\n", nrow(cross_dt)))

# ----------------------------------------------------------------------------
# 3) Spearman 相关：事件敏感度 vs 政治分数波动率
# ----------------------------------------------------------------------------
cat("[3/3] 计算 Spearman 相关...\n")

dbs <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
vol_cols <- paste0("vol_", dbs)

corr_results <- list()
for (trade_var in TRADE_VARS) {
  d <- cross_dt[trade == trade_var]
  for (vc in vol_cols) {
    db_name <- gsub("vol_", "", vc)
    pair <- d[, .(sensitivity, vol = get(vc))]
    pair <- pair[complete.cases(pair)]
    if (nrow(pair) < 5) next
    test <- cor.test(pair$sensitivity, pair$vol, method = "spearman")
    corr_results[[length(corr_results) + 1]] <- data.table(
      trade = trade_var,
      db = db_name,
      rho = as.numeric(test$estimate),
      pvalue = as.numeric(test$p.value),
      n = nrow(pair)
    )
  }
}

corr_out <- rbindlist(corr_results, use.names = TRUE)
corr_out[, sig := ifelse(pvalue < 0.01, "***", ifelse(pvalue < 0.05, "**", ifelse(pvalue < 0.10, "*", "")))]
corr_out[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

fwrite(corr_out, file.path(OUT_DIR, "10e_cross_db_correlation.csv"))
cat(sprintf("✓ 10e_cross_db_correlation.csv 已保存 (%d 行)\n", nrow(corr_out)))
print(corr_out[order(trade, db)])

# ----------------------------------------------------------------------------
# 4) 绘图
# ----------------------------------------------------------------------------
cat("绘图...\n")

plot_data <- melt(cross_dt, id.vars = c("ISO", "Country", "trade", "sensitivity"),
                  measure.vars = vol_cols, variable.name = "db", value.name = "vol")
plot_data[, db := gsub("vol_", "", db)]
plot_data <- plot_data[!is.na(vol) & !is.na(sensitivity)]
plot_data[, trade_label := factor(trade, levels = TRADE_VARS, labels = c("总贸易", "出口", "进口"))]

# 在每个面板添加相关系数标签
corr_labels <- corr_out[, .(trade_label, db, label = sprintf("ρ=%.2f%s", rho, sig))]

p <- ggplot(plot_data, aes(x = vol, y = sensitivity)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(aes(color = db), alpha = 0.7, size = 2.5) +
  geom_text(aes(label = ISO), size = 2.5, vjust = -0.5, check_overlap = TRUE) +
  geom_smooth(method = "lm", se = FALSE, linetype = "dashed", color = "black", linewidth = 0.6) +
  geom_text(data = corr_labels,
            aes(x = Inf, y = Inf, label = label),
            hjust = 1.1, vjust = 1.2, color = "black", size = 3, inherit.aes = FALSE) +
  facet_grid(trade_label ~ db, scales = "free") +
  labs(
    title = "交叉验证：事件驱动国家敏感度 vs 四库政治分数波动率",
    subtitle = "Spearman 秩相关；虚线为 OLS 拟合线",
    x = "政治分数标准差（波动率）",
    y = "事件敏感度（beta_Negative - beta_Positive）",
    color = "数据库"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none",
        strip.text = element_text(face = "bold", size = 9))

ggsave(file.path(FIG_DIR, "10e_cross_db_correlation.png"), p, width = 12, height = 8, dpi = 300)
cat("✓ 已保存 10e_cross_db_correlation.png\n")
