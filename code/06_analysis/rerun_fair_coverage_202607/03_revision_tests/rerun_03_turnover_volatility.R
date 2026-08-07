# rerun_03_turnover_volatility.R — R1c: 03_换届波动率重估, self-contained fair/full rerun

suppressMessages({library(data.table); library(zoo)})

mode <- commandArgs(trailingOnly = TRUE)[1]
stopifnot(mode %in% c("full", "fair"))
BASE <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果"
SCORE_DIR <- file.path(BASE, "3.2 双边关系分析基于月度政治分数/全新事件研究法",
                       if (mode == "fair") "data_fair" else "data")
CM <- file.path(BASE, "重跑_公平覆盖期_202607/02_事件研究套件", mode,
                "04_领导人换届效应与双边关系波动/code/results/country_metrics.csv")
OUT <- file.path(BASE, "重跑_公平覆盖期_202607/03_修订检验", mode, "03_换届波动率重估/results")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

sc <- fread(file.path(SCORE_DIR, "scores_v3_GDELT_ICEWS_2025.csv"), encoding = "UTF-8")
setnames(sc, sub("^\ufeff", "", names(sc)))
sc[, month := as.Date(month)]

vol <- sc[, {
  z <- zscore[order(month)]
  .(vol_sd12m = mean(rollapply(z, 12, sd, fill = NA, align = "right"), na.rm = TRUE),
    vol_range12m = mean(rollapply(z, 12, function(x) max(x) - min(x), fill = NA, align = "right"), na.rm = TRUE))
}, by = .(db, country)]

cm <- fread(CM, encoding = "UTF-8")
nto <- unique(cm[, .(country, n_turnovers)])
m <- merge(nto, vol, by = "country")

res <- rbindlist(lapply(c("GDELT", "ICEWS"), function(d) {
  rbindlist(lapply(c("vol_sd12m", "vol_range12m"), function(vm) {
    sub <- m[db == d]
    pe <- cor.test(sub$n_turnovers, sub[[vm]], method = "pearson")
    sp <- suppressWarnings(cor.test(sub$n_turnovers, sub[[vm]], method = "spearman"))
    data.table(db = d, vol_measure = vm, n = nrow(sub),
               pearson_r = unname(pe$estimate), pearson_p = pe$p.value,
               spearman_r = unname(sp$estimate), spearman_p = sp$p.value)
  }))
}))
fwrite(res, file.path(OUT, "correlation_summary.csv"))
fwrite(m, file.path(OUT, "turnover_volatility_redone.csv"))
cat(sprintf("[%s] correlation_summary.csv saved (%d rows)\n", mode, nrow(res)))
print(res)
