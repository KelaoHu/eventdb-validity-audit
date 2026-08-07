# 03 换届与波动率重估 —— 对应评审问题 C4

library(data.table); library(ggplot2)

base <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果"
new_dir <- file.path(base, "3.2 双边关系分析基于月度政治分数/全新事件研究法/04_领导人换届效应与双边关系波动")
old_csv <- file.path(base, "3.2 双边关系分析基于月度政治分数/事件研究法（25国）/领导人换届效应与双边关系波动/检验结果CSV")
out <- file.path(base, "修订补充检验_202607/03_换届与波动率重估")

cm  <- fread(file.path(new_dir, "results/country_metrics.csv"))              # country,n_turnovers,db,mean_vol
rb  <- fread(file.path(new_dir, "robustness/m4_robustness_vol_measures.csv"))# + vol_sd12m, vol_range12m

# --- 25国明细（宽表） ---
wide <- dcast(rb[, .(country, n_turnovers, db, vol_sd12m, vol_range12m)],
              country + n_turnovers ~ db, value.var = c("vol_sd12m","vol_range12m"))
setnames(wide, c("country","n_turnovers","sd12m_GDELT","sd12m_ICEWS","range12m_GDELT","range12m_ICEWS"))
wide <- wide[order(-n_turnovers)]
fwrite(wide, file.path(out, "results/turnover_volatility_redone.csv"))

# --- 相关系数：2库 × 2波动率测度 × Pearson/Spearman ---
cors <- rbindlist(lapply(c("GDELT","ICEWS"), function(d) {
  sub <- rb[db == d]
  rbindlist(lapply(c("vol_sd12m","vol_range12m"), function(vm) {
    x <- sub$n_turnovers; y <- sub[[vm]]
    data.table(db = d, vol_measure = vm, n = nrow(sub),
               pearson_r  = cor.test(x, y, method="pearson")$estimate,
               pearson_p  = cor.test(x, y, method="pearson")$p.value,
               spearman_r = cor.test(x, y, method="spearman")$estimate,
               spearman_p = cor.test(x, y, method="spearman")$p.value)
  }))
}))
fwrite(cors, file.path(out, "results/correlation_summary.csv"))
print(cors)

# --- 新旧模块对照 ---
old_cor <- fread(file.path(old_csv, "correlation_turnover_volatility.csv"))
old_vol <- fread(file.path(old_csv, "country_volatility_summary.csv"))
old_agg <- old_vol[direction == "Aggregated"]
cmp <- data.table(
  item = c("Pearson r (Aggregated)","Spearman rho (Aggregated)","Japan sd","Japan rank (lowest?)","Singapore sd","Singapore/Japan ratio"),
  old_module_旧数据 = c(round(old_cor[direction=="Aggregated", pearson_r],4),
                        round(old_cor[direction=="Aggregated", spearman_r],4),
                        round(old_agg[country=="Japan", avg_sd_score],4),
                        paste0("No — rank ", sum(old_agg$avg_sd_score < old_agg[country=="Japan", avg_sd_score]) + 1, "/25"),
                        round(old_agg[country=="Singapore", avg_sd_score],4),
                        round(old_agg[country=="Singapore", avg_sd_score]/old_agg[country=="Japan", avg_sd_score],2)),
  draft_初稿 = c("-0.60","-0.70","0.73","Yes — '25国最低'","1.04","'3倍以上'"),
  new_module_新数据 = c(round(cors[db=="GDELT" & vol_measure=="vol_sd12m", pearson_r],4),
                        round(cors[db=="GDELT" & vol_measure=="vol_sd12m", spearman_r],4),
                        round(wide[country=="Japan", sd12m_GDELT],4),
                        paste0("No — rank ", sum(wide$sd12m_GDELT < wide[country=="Japan", sd12m_GDELT]) + 1, "/25 (US ", round(wide[country=="United States", sd12m_GDELT],3), " lowest)"),
                        round(wide[country=="Singapore", sd12m_GDELT],4),
                        round(wide[country=="Singapore", sd12m_GDELT]/wide[country=="Japan", sd12m_GDELT],2))
)
fwrite(cmp, file.path(out, "results/old_vs_new_comparison.csv"))
print(cmp)

# --- 散点图 ---
pd <- rb[, .(country, n_turnovers, db, vol = vol_sd12m)]
lab_countries <- c("Japan","Singapore","United States","Thailand","Australia","South Korea")
p <- ggplot(pd, aes(x = n_turnovers, y = vol)) +
  geom_jitter(width = 0.08, height = 0, size = 2.5, color = "steelblue", alpha = 0.8) +
  geom_smooth(method = "lm", se = TRUE, color = "darkred", linewidth = 0.7) +
  geom_text(data = pd[country %in% lab_countries], aes(label = country),
            vjust = -0.8, size = 3.2) +
  facet_wrap(~db) +
  labs(title = "Leadership Turnover vs. Political-Index Volatility (25 countries)",
       subtitle = "New data pipeline (scores_v3). GDELT: r = -0.128 (p = .49); ICEWS: r = +0.050 (p = .81)",
       x = "Number of leadership turnovers (2002-2025)",
       y = "Volatility (mean 12-month rolling SD of monthly index)") +
  theme_bw(base_size = 12)
ggsave(file.path(out, "figures/turnover_vs_volatility.png"), p, width = 10, height = 5.5, dpi = 320)
cat("DONE\n")
