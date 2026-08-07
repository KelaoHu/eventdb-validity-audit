# audit_m1_phoenix_fill.R — B1: M1 Phoenix fill-window (2019-04..2019-12) sensitivity

suppressMessages({library(dplyr); library(tidyr); library(readr); library(lubridate)})

SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUTDIR <- "../results"
set.seed(20260726)

events <- read_csv(file.path(SD,"events_713.csv"), show_col_types=FALSE, locale=locale(encoding="UTF-8")) %>%
  filter(event_type_original!="leader_visit", impact %in% c("positive","negative")) %>%
  mutate(event_date_ym=ymd(paste0(event_date,"-01")),
         event_id=paste(country_en, event_date, event_name, sep="|"))
sc <- read_csv(file.path(SD,"scores_v1_4DB_2019.csv"), show_col_types=FALSE, locale=locale(encoding="UTF-8")) %>%
  mutate(month=ymd(month))

H <- c(0,1,3,6,12); NB <- 500

build_shocks <- function(ev_df, dbs) {
  shocks <- list()
  for (db in dbs) {
    d <- sc %>% filter(db==!!db) %>% select(country, month, value)
    for (i in seq_len(nrow(ev_df))) {
      ev <- ev_df[i,]; ed <- ev$event_date_ym
      s <- d %>% filter(country==ev$country_en) %>% arrange(month)
      if (nrow(s)==0) next
      pre <- s %>% filter(month >= ed %m-% months(12), month <= ed %m-% months(7))
      if (nrow(pre) < 4) next
      bl <- mean(pre$value, na.rm=TRUE); if (is.na(bl)) next
      for (h in H) {
        post <- s %>% filter(month == ed %m+% months(h))
        if (nrow(post)>0 && !is.na(post$value[1]))
          shocks[[length(shocks)+1]] <- tibble(db=db, direction=ev$impact, event_id=ev$event_id, h=h, shock=post$value[1]-bl)
      }
    }
  }
  bind_rows(shocks)
}

summ <- function(sh, dbs) {
  res <- list()
  for (db in dbs) for (dirn in c("positive","negative")) {
    sub <- sh %>% filter(db==!!db, direction==dirn)
    wide <- sub %>% select(event_id, h, shock) %>% pivot_wider(names_from=h, values_from=shock, names_prefix="h") %>% as.data.frame()
    hm <- as.matrix(wide[, paste0("h",H), drop=FALSE])
    for (j in seq_along(H)) {
      x <- hm[,j]; ok <- !is.na(x); xo <- x[ok]
      if (sum(ok) < 5) next
      mu <- mean(xo); tt <- t.test(xo)
      idx <- which(ok); boot <- numeric(NB)
      for (b in seq_len(NB)) boot[b] <- mean(x[sample(idx, length(idx), replace=TRUE)], na.rm=TRUE)
      p_boot <- min(1, 2*min(mean(boot<=0), mean(boot>=0)))
      res[[length(res)+1]] <- tibble(db=db, direction=dirn, h=H[j], response=mu,
        se_boot=sd(boot), p_boot=p_boot, p_ttest=tt$p.value, n_events=sum(ok))
    }
  }
  bind_rows(res)
}

sh_full <- build_shocks(events, c("GDELT","ICEWS","Phoenix","Tsinghua"))
full <- summ(sh_full, c("GDELT","ICEWS","Phoenix","Tsinghua")) %>% mutate(variant="full")

ev_tr <- events %>% filter(event_date_ym <= ymd("2019-03-01"))
sh_tr  <- build_shocks(ev_tr, c("Phoenix"))
tr   <- summ(sh_tr, c("Phoenix")) %>% mutate(variant="phx_trunc")

both <- bind_rows(full, tr)
write_csv(both, file.path(OUTDIR, "m1_phoenix_fill_full_vs_trunc.csv"))

cat("== Phoenix BEFORE (full, archive) vs AFTER (events <= 2019-03) ==\n")
cmp <- bind_rows(full %>% filter(db=="Phoenix"), tr) %>%
  mutate(response=round(response,3), p_boot=round(p_boot,4), p_ttest=signif(p_ttest,3)) %>%
  select(variant, direction, h, response, p_boot, p_ttest, n_events)
print(as.data.frame(cmp), row.names=FALSE)

# how many Phoenix events dropped
n_full <- sh_full %>% filter(db=="Phoenix") %>% distinct(event_id) %>% nrow()
n_tr   <- sh_tr %>% distinct(event_id) %>% nrow()
cat(sprintf("Phoenix events: full=%d, trunc=%d (dropped %d in fill window 2019-04..12)\n", n_full, n_tr, n_full-n_tr))

# replication check vs archive (Phoenix neg h=0 should be -1.9785)
arc <- full %>% filter(db=="Phoenix", direction=="negative", h==0)
cat(sprintf("replication check: Phoenix neg h=0 = %.4f (archive -1.9785)\n", arc$response))
cat("saved m1_phoenix_fill_full_vs_trunc.csv\n")
