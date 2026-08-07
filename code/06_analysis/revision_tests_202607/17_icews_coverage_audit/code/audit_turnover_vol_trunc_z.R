# audit_turnover_vol_trunc.R — B3: turnover-volatility correlation, ICEWS full vs <=2023-04

suppressMessages({library(data.table); library(zoo)})

BASE <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果"
SD <- file.path(BASE, "3.2 双边关系分析基于月度政治分数/全新事件研究法/data")
RB <- fread(file.path(BASE, "3.2 双边关系分析基于月度政治分数/全新事件研究法/04_领导人换届效应与双边关系波动/robustness/m4_robustness_vol_measures.csv"))
OUT <- "../results"
CUTOFF <- "2023-04"

sc <- fread(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), encoding="UTF-8")
setnames(sc, sub("^\ufeff", "", names(sc)))

vol_of <- function(d) {
  d <- d[order(month)]
  data.table(
    vol_sd12m = mean(rollapply(d$zscore, 12, sd, fill = NA, align = "right"), na.rm = TRUE),
    vol_range12m = mean(rollapply(d$zscore, 12, function(x) max(x) - min(x), fill = NA, align = "right"), na.rm = TRUE))
}

nto <- unique(RB[, .(country, n_turnovers)])
res <- list()
for (dbn in c("GDELT", "ICEWS")) {
  for (variant in c("full", "trunc_le2023_04")) {
    d <- sc[db == dbn]
    if (variant == "trunc_le2023_04") d <- d[format(as.Date(month), "%Y-%m") <= CUTOFF]
    v <- d[, vol_of(.SD), by = country]
    m <- merge(nto, v, by = "country")
    for (vm in c("vol_sd12m", "vol_range12m")) {
      x <- m$n_turnovers; y <- m[[vm]]
      pe <- cor.test(x, y, method = "pearson"); sp <- suppressWarnings(cor.test(x, y, method = "spearman"))
      cat(sprintf("%-6s %-17s %-13s n=%d pearson=% .4f (p=%.3f) spearman=% .4f (p=%.3f)\n",
                  dbn, variant, vm, nrow(m), pe$estimate, pe$p.value, sp$estimate, sp$p.value))
      res[[length(res)+1]] <- data.table(db = dbn, variant, vol_measure = vm, n = nrow(m),
        pearson_r = unname(pe$estimate), pearson_p = pe$p.value,
        spearman_r = unname(sp$estimate), spearman_p = sp$p.value)
    }
  }
}
out <- rbindlist(res)
fwrite(out, file.path(OUT, "turnover_vol_full_vs_trunc.csv"))
cat("saved turnover_vol_full_vs_trunc.csv\n")
