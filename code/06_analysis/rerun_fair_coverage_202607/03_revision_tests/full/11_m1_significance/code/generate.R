# 11_M1事件研究显著性补算

suppressMessages({library(dplyr); library(tidyr); library(readr); library(ggplot2); library(lubridate)})

SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
dir.create("../results", showWarnings=FALSE, recursive=TRUE)
dir.create("../figures", showWarnings=FALSE, recursive=TRUE)
set.seed(20260726)

events <- read_csv(file.path(SD,"events_713.csv"), show_col_types=FALSE, locale=locale(encoding="UTF-8")) %>%
  filter(event_type_original!="leader_visit", impact %in% c("positive","negative")) %>%
  mutate(event_date_ym=ymd(paste0(event_date,"-01")),
         event_id=paste(country_en, event_date, event_name, sep="|"))
sc <- read_csv(file.path(SD,"scores_v1_4DB_2019.csv"), show_col_types=FALSE, locale=locale(encoding="UTF-8")) %>%
  mutate(month=ymd(month))

H <- c(0,1,3,6,12)
NB <- 500

# ---- event-level shocks ----
shocks <- list()
for (db in c("GDELT","ICEWS","Phoenix","Tsinghua")) {
  d <- sc %>% filter(db==!!db) %>% select(country, month, value)
  for (i in seq_len(nrow(events))) {
    ev <- events[i,]; ed <- ev$event_date_ym
    s <- d %>% filter(country==ev$country_en) %>% arrange(month)
    if (nrow(s)==0) next
    pre <- s %>% filter(month >= ed %m-% months(12), month <= ed %m-% months(7))
    if (nrow(pre) < 4) next                       # require >=4 of 6 baseline months
    bl <- mean(pre$value, na.rm=TRUE); if (is.na(bl)) next
    for (h in H) {
      post <- s %>% filter(month == ed %m+% months(h))
      if (nrow(post)>0 && !is.na(post$value[1]))
        shocks[[length(shocks)+1]] <- tibble(db=db, direction=ev$impact, event_id=ev$event_id,
                                             country=ev$country_en, h=h, shock=post$value[1]-bl)
    }
  }
}
sh <- bind_rows(shocks)
cat(sprintf("Event-h observations: %d\n", nrow(sh)))

# ---- cluster bootstrap (resample events) + t-test per db x direction x h ----
res <- list()
for (db in c("GDELT","ICEWS","Phoenix","Tsinghua")) for (dirn in c("positive","negative")) {
  sub <- sh %>% filter(db==!!db, direction==dirn)
  evs <- unique(sub$event_id)
  wide <- sub %>% select(event_id, h, shock) %>%
    pivot_wider(names_from=h, values_from=shock, names_prefix="h") %>% as.data.frame()
  hm <- as.matrix(wide[, paste0("h",H), drop=FALSE])
  for (j in seq_along(H)) {
    x <- hm[,j]; ok <- !is.na(x); xo <- x[ok]
    if (sum(ok) < 5) next
    mu <- mean(xo); tt <- t.test(xo)
    # cluster bootstrap over events with non-missing shock at this h
    idx <- which(ok); boot <- numeric(NB)
    for (b in seq_len(NB)) boot[b] <- mean(x[sample(idx, length(idx), replace=TRUE)], na.rm=TRUE)
    p_boot <- 2*min(mean(boot<=0), mean(boot>=0)); p_boot <- min(1, p_boot)
    res[[length(res)+1]] <- tibble(db=db, direction=dirn, h=H[j], response=mu,
      se_boot=sd(boot), ci_lo=quantile(boot,.025,names=FALSE), ci_hi=quantile(boot,.975,names=FALSE),
      p_boot=p_boot, p_ttest=tt$p.value, n_events=sum(ok))
  }
}
out <- bind_rows(res) %>% arrange(db, direction, h)
write_csv(out, "../results/m1_irf_significance.csv")

# ---- figure: 4-DB IRF comparison, two panels ----
pd <- out %>% mutate(direction=recode(direction, positive="Positive events", negative="Negative events"))
p <- ggplot(pd, aes(x=h, y=response, color=db, fill=db, group=db)) +
  geom_hline(yintercept=0, linetype="dashed", color="grey60") +
  geom_ribbon(aes(ymin=ci_lo, ymax=ci_hi), alpha=0.12, color=NA) +
  geom_line(linewidth=0.8) + geom_point(size=2.2) +
  facet_wrap(~direction, ncol=2) +
  scale_x_continuous(breaks=H) +
  scale_color_manual(values=c(GDELT="#2166ac", ICEWS="#b2182b", Phoenix="#1b7837", Tsinghua="#e08214")) +
  scale_fill_manual(values=c(GDELT="#2166ac", ICEWS="#b2182b", Phoenix="#1b7837", Tsinghua="#e08214")) +
  labs(title="Event-study impulse responses by database (M1)",
       subtitle="Response = index at t+h minus baseline (mean of t-12 to t-7). Shaded bands: 95% cluster-bootstrap CI (500 reps, events resampled). 4DB sample 2002-2019.",
       x="Horizon h (months after event)", y="Mean response (index units)", color="Database", fill="Database") +
  theme_bw(base_size=11) +
  theme(legend.position="bottom", strip.background=element_rect(fill="grey92"),
        plot.title=element_text(face="bold"))
ggsave("../figures/m1_irf_four_db.png", p, width=9.5, height=5.5, dpi=320)

cat("=== Mean response (p_boot) ===\n")
print(as.data.frame(out %>% mutate(response=round(response,3), se_boot=round(se_boot,3),
  p_boot=round(p_boot,4), p_ttest=signif(p_ttest,3)) %>%
  select(db,direction,h,response,se_boot,p_boot,p_ttest,n_events)), row.names=FALSE)
cat("Done.\n")
