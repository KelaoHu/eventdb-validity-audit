# audit_test1_alliance.R — 联盟交互检验：全期复制 vs 截断(≤2023-04) 对照

library(tidyverse); library(lubridate); library(fixest)
SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/17_ICEWS覆盖期审计/results"
CUTOFF <- as.Date("2023-04-01")
US_ALLY <- c("Japan", "South Korea", "Australia", "United Kingdom", "Canada", "Philippines")
US_ALLY_NARROW <- c("Japan", "South Korea", "Australia", "Philippines")

events <- read_csv(file.path(SD, "events_713.csv"), show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")))
sc0 <- read_csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), show_col_types = FALSE, locale = locale(encoding = "UTF-8"))
ev <- events %>%
  filter(event_type_original != "leader_visit", impact %in% c("positive", "negative")) %>%
  group_by(country_en, event_date_ym) %>%
  summarise(neg = any(impact == "negative"), pos = any(impact == "positive"), .groups = "drop")

lin_comb <- function(fit, idx) {
  b <- coef(fit)[idx]; V <- vcov(fit)[idx, idx]
  est <- sum(b); se <- sqrt(sum(V)); p <- 2 * pnorm(-abs(est / se))
  c(est = est, se = se, p = p)
}
run_lp <- function(sc, dbname, ally_set, spec) {
  panel <- sc %>% filter(db == dbname) %>%
    select(country, month, value) %>%
    left_join(ev, by = c("country" = "country_en", "month" = "event_date_ym")) %>%
    mutate(neg = as.numeric(replace_na(neg, FALSE)), pos = as.numeric(replace_na(pos, FALSE)),
           ally = country %in% ally_set,
           neg_ally = neg * as.numeric(ally), pos_ally = pos * as.numeric(ally)) %>%
    arrange(country, month) %>% group_by(country) %>%
    mutate(l1 = lag(value, 1), l2 = lag(value, 2), l3 = lag(value, 3),
           bl = rowMeans(cbind(l1, l2, l3), na.rm = TRUE)) %>% ungroup()
  rows <- list()
  for (h in 0:6) {
    d <- panel %>% group_by(country) %>% mutate(leadv = lead(value, h)) %>% ungroup()
    d <- if (spec == "change") d %>% mutate(y = leadv - bl) else d %>% mutate(y = leadv)
    d <- d %>% filter(!is.na(y), !is.nan(y))
    fit <- feols(y ~ neg + neg_ally + pos + pos_ally | country + month, data = d, cluster = ~country + month)
    at <- lin_comb(fit, c("neg", "neg_ally")); ct <- coeftable(fit)
    rows[[h + 1]] <- tibble(
      db = dbname, spec = spec, ally_set = ifelse(identical(ally_set, US_ALLY), "M3_six", "narrow4"), h = h,
      beta_neg_nonally = ct["neg", "Estimate"], p_neg_nonally = ct["neg", "Pr(>|t|)"],
      beta_interact = ct["neg_ally", "Estimate"], p_interact = ct["neg_ally", "Pr(>|t|)"],
      beta_neg_ally_total = at["est"], p_neg_ally_total = at["p"], n_obs = nobs(fit))
  }
  bind_rows(rows)
}

modes <- list(full = sc0, trunc = sc0 %>% filter(month <= CUTOFF))
all_tab <- list()
for (m in names(modes)) {
  sc <- modes[[m]]
  tab <- bind_rows(
    run_lp(sc, "GDELT", US_ALLY, "change"), run_lp(sc, "ICEWS", US_ALLY, "change"),
    run_lp(sc, "GDELT", US_ALLY_NARROW, "change"),
    run_lp(sc, "GDELT", US_ALLY, "level"),  run_lp(sc, "ICEWS", US_ALLY, "level"))
  all_tab[[m]] <- tab %>% mutate(variant = m)
}
out <- bind_rows(all_tab) %>% select(variant, everything())
write_csv(out, file.path(OUT, "test1_alliance_full_vs_trunc.csv"))
print(out %>% filter(h %in% c(0, 1)) %>%
        select(variant, db, spec, ally_set, h, beta_neg_nonally, p_neg_nonally,
               beta_interact, p_interact, n_obs), n = 40)
cat("Done audit test1.\n")
