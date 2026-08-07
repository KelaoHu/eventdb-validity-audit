# Task 03: Leadership turnover vs political-score volatility, redone.

suppressPackageStartupMessages({ library(zoo); library(ggplot2) })

SD  <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/03_换届与波动率重估"
dir.create(file.path(OUT, "results"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(OUT, "figures"), showWarnings = FALSE, recursive = TRUE)

## --- leaders ---
ld <- read.csv(file.path(SD, "leaders.csv"), fileEncoding = "UTF-8-BOM",
               stringsAsFactors = FALSE, check.names = FALSE)
names(ld)[1] <- "country"; names(ld)[7] <- "start"
ld$start <- as.Date(paste0(ld$start, "-01"))
tab_ld <- aggregate(start ~ country, ld,
                    function(s) c(n_leaders = length(s),
                                  n_turnovers = sum(s >= as.Date("2002-01-01"))))
leaders_df <- data.frame(country = tab_ld$country,
                         n_leaders = tab_ld$start[, "n_leaders"],
                         n_turnovers = tab_ld$start[, "n_turnovers"])

## --- scores / volatility ---
sc <- read.csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"),
               fileEncoding = "UTF-8", stringsAsFactors = FALSE)
sc$month <- as.Date(sc$month)
vol_rows <- list()
for (db in c("GDELT", "ICEWS")) {
  for (cty in sort(unique(sc$country))) {
    d <- sc[sc$db == db & sc$country == cty, ]; d <- d[order(d$month), ]
    rsd <- rollapply(d$value, width = 12, FUN = sd, fill = NA, align = "right")
    vol_rows[[length(vol_rows) + 1]] <- data.frame(
      country = cty, db = db,
      roll12_sd_mean = mean(rsd, na.rm = TRUE),
      fullsample_sd  = sd(d$value))
  }
}
vol <- do.call(rbind, vol_rows)
m <- merge(leaders_df, vol, by = "country")
cat("countries matched:", nrow(m) / 2, "\n")

## --- wide detail table ---
wide <- merge(leaders_df,
              reshape(vol, idvar = "country", timevar = "db", direction = "wide"),
              by = "country")
names(wide) <- gsub("roll12_sd_mean.", "roll12_sd_mean_", names(wide))
names(wide) <- gsub("fullsample_sd.", "fullsample_sd_", names(wide))
wide <- wide[order(wide$country), ]
write.csv(wide, file.path(OUT, "results", "turnover_volatility_redone.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

## --- correlation summary ---
cor_rows <- list()
for (db in c("GDELT", "ICEWS")) {
  sub <- m[m$db == db, ]
  for (vm in c("roll12_sd_mean", "fullsample_sd")) {
    pt <- cor.test(sub$n_turnovers, sub[[vm]], method = "pearson")
    st <- suppressWarnings(cor.test(sub$n_turnovers, sub[[vm]], method = "spearman"))
    cor_rows[[length(cor_rows) + 1]] <- data.frame(
      db = db, vol_measure = vm,
      pearson_r  = round(unname(pt$estimate), 4),
      pearson_p  = round(pt$p.value, 4),
      spearman_rho = round(unname(st$estimate), 4),
      spearman_p   = round(st$p.value, 4))
  }
}
cor_tab <- do.call(rbind, cor_rows)
write.csv(cor_tab, file.path(OUT, "results", "correlation_summary.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
print(cor_tab)

## extremes for README
for (db in c("GDELT", "ICEWS")) {
  sub <- m[m$db == db, ]
  o <- sub[order(sub$roll12_sd_mean), ]
  cat(db, "roll12_sd lowest:", o$country[1], round(o$roll12_sd_mean[1], 3),
      "| highest:", o$country[nrow(o)], round(o$roll12_sd_mean[nrow(o)], 3),
      "| Japan:", round(sub$roll12_sd_mean[sub$country == "Japan"], 3),
      "rank", which(o$country == "Japan"), "of", nrow(o),
      "| Singapore:", round(sub$roll12_sd_mean[sub$country == "Singapore"], 3), "\n")
}
cat("Japan leaders/turnovers:", wide$n_leaders[wide$country == "Japan"],
    wide$n_turnovers[wide$country == "Japan"],
    "| Singapore:", wide$n_leaders[wide$country == "Singapore"],
    wide$n_turnovers[wide$country == "Singapore"], "\n")

## --- scatter plot ---
m$lab <- ifelse(m$country %in% c("Japan", "Singapore", "United States",
                                 "Thailand", "Germany"), m$country, NA)
p <- ggplot(m, aes(x = n_turnovers, y = roll12_sd_mean)) +
  geom_smooth(method = "lm", se = TRUE, color = "#2166AC",
              linewidth = 0.7, alpha = 0.15) +
  geom_point(size = 2, color = "grey30") +
  geom_text(aes(label = lab), vjust = -0.8, size = 3.2, na.rm = TRUE,
            fontface = "bold") +
  facet_wrap(~ db) +
  labs(title = "Leadership turnover vs political-score volatility (25 countries, 2002-2025)",
       subtitle = "x: number of leaders whose tenure began after 2002-01; y: mean of 12-month rolling sd of monthly political score",
       x = "Leadership turnovers (count)", y = "Volatility (mean 12m rolling sd)",
       caption = "Labels: Japan / Singapore / United States / Thailand / Germany. Shaded band: 95% CI of OLS fit.") +
  theme_bw(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 12))
ggsave(file.path(OUT, "figures", "turnover_vs_volatility.png"),
       p, width = 10, height = 5.5, dpi = 320)
cat("Task 03 done.\n")
