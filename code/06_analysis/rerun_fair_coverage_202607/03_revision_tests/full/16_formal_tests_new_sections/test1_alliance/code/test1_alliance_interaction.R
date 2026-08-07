# 检验1：美国盟友 × 负面事件暴露 正式交互检验（局部投影式面板回归）

library(tidyverse); library(lubridate); library(fixest)
set.seed(20260716)

SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT <- "../results"; dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

US_ALLY <- c("Japan", "South Korea", "Australia", "United Kingdom", "Canada", "Philippines")
US_ALLY_NARROW <- c("Japan", "South Korea", "Australia", "Philippines")

events <- read_csv(file.path(SD, "events_713.csv"), show_col_types = FALSE,
                   locale = locale(encoding = "UTF-8")) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")))
sc <- read_csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), show_col_types = FALSE,
               locale = locale(encoding = "UTF-8"))

# 事件暴露口径与 M3/M7 一致：剔除 leader_visit，仅正/负事件（168正/110负）
ev <- events %>%
  filter(event_type_original != "leader_visit", impact %in% c("positive", "negative")) %>%
  group_by(country_en, event_date_ym) %>%
  summarise(neg = any(impact == "negative"), pos = any(impact == "positive"), .groups = "drop")
cat(sprintf("Exposure cells: %d country-months (neg=%d, pos=%d)\n",
            nrow(ev), sum(ev$neg), sum(ev$pos)))

lin_comb <- function(fit, idx) {
  b <- coef(fit)[idx]; V <- vcov(fit)[idx, idx]
  est <- sum(b); se <- sqrt(sum(V)); p <- 2 * pnorm(-abs(est / se))
  c(est = est, se = se, p = p)
}

run_lp <- function(dbname, ally_set, spec) {
  panel <- sc %>% filter(db == dbname) %>%
    select(country, month, value) %>%
    left_join(ev, by = c("country" = "country_en", "month" = "event_date_ym")) %>%
    mutate(neg = as.numeric(replace_na(neg, FALSE)), pos = as.numeric(replace_na(pos, FALSE)),
           ally = country %in% ally_set,
           neg_ally = neg * as.numeric(ally), pos_ally = pos * as.numeric(ally)) %>%
    arrange(country, month) %>% group_by(country) %>%
    mutate(l1 = lag(value, 1), l2 = lag(value, 2), l3 = lag(value, 3),
           bl = rowMeans(cbind(l1, l2, l3), na.rm = TRUE)) %>%
    ungroup()
  rows <- list()
  for (h in 0:6) {
    d <- panel %>% group_by(country) %>% mutate(leadv = lead(value, h)) %>% ungroup()
    d <- if (spec == "change") d %>% mutate(y = leadv - bl) else d %>% mutate(y = leadv)
    d <- d %>% filter(!is.na(y), !is.nan(y))
    fit <- feols(y ~ neg + neg_ally + pos + pos_ally | country + month,
                 data = d, cluster = ~country + month)
    at <- lin_comb(fit, c("neg", "neg_ally"))
    ct <- coeftable(fit)
    rows[[h + 1]] <- tibble(
      db = dbname, spec = spec, ally_set = ifelse(identical(ally_set, US_ALLY), "M3_six", "narrow4"), h = h,
      beta_neg_nonally = ct["neg", "Estimate"], se_neg_nonally = ct["neg", "Std. Error"],
      p_neg_nonally = ct["neg", "Pr(>|t|)"],
      beta_interact = ct["neg_ally", "Estimate"], se_interact = ct["neg_ally", "Std. Error"],
      p_interact = ct["neg_ally", "Pr(>|t|)"],
      beta_neg_ally_total = at["est"], se_neg_ally_total = at["se"], p_neg_ally_total = at["p"],
      beta_pos_nonally = ct["pos", "Estimate"], p_pos_nonally = ct["pos", "Pr(>|t|)"],
      beta_pos_interact = ct["pos_ally", "Estimate"], p_pos_interact = ct["pos_ally", "Pr(>|t|)"],
      n_obs = nobs(fit), n_countries = n_distinct(d$country),
      n_neg_exposed = sum(d$neg), n_neg_exposed_ally = sum(d$neg_ally))
  }
  bind_rows(rows)
}

mk_panel <- function(dbname, ally_set) {
  sc %>% filter(db == dbname) %>%
    select(country, month, value) %>%
    left_join(ev, by = c("country" = "country_en", "month" = "event_date_ym")) %>%
    mutate(neg = as.numeric(replace_na(neg, FALSE)), pos = as.numeric(replace_na(pos, FALSE)),
           ally = country %in% ally_set,
           neg_ally = neg * as.numeric(ally), pos_ally = pos * as.numeric(ally)) %>%
    arrange(country, month) %>% group_by(country) %>%
    mutate(l1 = lag(value, 1), l2 = lag(value, 2), l3 = lag(value, 3),
           bl = rowMeans(cbind(l1, l2, l3), na.rm = TRUE)) %>% ungroup()
}

tab <- bind_rows(
  run_lp("GDELT", US_ALLY, "change"),  run_lp("ICEWS", US_ALLY, "change"),
  run_lp("GDELT", US_ALLY_NARROW, "change"),
  run_lp("GDELT", US_ALLY, "level"),   run_lp("ICEWS", US_ALLY, "level"))
write_csv(tab, file.path(OUT, "test1_lp_interaction.csv"))
print(tab %>% select(db, spec, ally_set, h, beta_neg_nonally, p_neg_nonally,
                     beta_interact, p_interact, beta_neg_ally_total, p_neg_ally_total), n = 42)

# ---- 500 次置换检验：打乱盟友标签（保持 |ally|=6），主设定(change)，h=0 与 h=1 ----
NPERM <- 500
countries_all <- sort(unique(sc$country))
panel_g <- mk_panel("GDELT", US_ALLY)

perm_est <- function(panel, h) {
  d <- panel %>% group_by(country) %>% mutate(leadv = lead(value, h)) %>% ungroup() %>%
    mutate(y = leadv - bl) %>% filter(!is.na(y), !is.nan(y))
  fit <- feols(y ~ neg + neg_ally + pos + pos_ally | country + month, data = d, cluster = ~country + month)
  coef(fit)["neg_ally"]
}
perm_summary <- list()
for (h in c(0, 1)) {
  obs_b <- perm_est(panel_g, h)
  perm_b <- numeric(NPERM)
  for (r in 1:NPERM) {
    fake_ally <- sample(countries_all, length(US_ALLY))
    p2 <- panel_g %>% mutate(ally = country %in% fake_ally,
                             neg_ally = neg * as.numeric(ally), pos_ally = pos * as.numeric(ally))
    perm_b[r] <- perm_est(p2, h)
    if (r %% 100 == 0) cat(sprintf("  h=%d perm %d/%d\n", h, r, NPERM))
  }
  p_two <- (1 + sum(abs(perm_b) >= abs(obs_b))) / (NPERM + 1)
  p_one <- (1 + sum(perm_b <= obs_b)) / (NPERM + 1)
  cat(sprintf("h=%d: obs interact=%.4f, perm two-sided p=%.4f, one-sided p=%.4f\n",
              h, obs_b, p_two, p_one))
  perm_summary[[length(perm_summary) + 1]] <- tibble(
    h = h, obs = obs_b, perm_mean = mean(perm_b), perm_sd = sd(perm_b),
    perm_q025 = quantile(perm_b, .025), perm_q975 = quantile(perm_b, .975),
    perm_p_twoside = p_two, perm_p_oneside_neg = p_one)
  write_csv(tibble(h = h, perm = 1:NPERM, beta_interact_perm = perm_b),
            file.path(OUT, sprintf("test1_permutation_draws_h%d.csv", h)))
}
tabp <- bind_rows(perm_summary)
write_csv(tabp, file.path(OUT, "test1_permutation_summary.csv"))
print(tabp)
cat("Done test1.\n")
