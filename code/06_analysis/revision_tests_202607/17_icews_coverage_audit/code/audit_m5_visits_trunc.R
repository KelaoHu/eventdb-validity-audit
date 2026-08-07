# audit_m5_visits_trunc.R — M5 signal-cost gradient, full vs truncated (Option A)

suppressMessages({library(tidyverse); library(lubridate)})

SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUTDIR <- "../results"
CUTOFF <- ymd("2023-04-01")

events <- read_csv(file.path(SD, "events_712.csv"), show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")))
visits <- events %>% filter(event_type_original == "leader_visit")

sc <- read_csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), show_col_types = FALSE, locale = locale(encoding = "UTF-8"))

classify_visit_4 <- function(df) {
  df %>%
    mutate(category_4 = case_when(
      event_category_en == "Remote talk / virtual meeting" ~ "Remote talk",
      visit_direction == "china_to_partner" ~ "Chinese outbound visit",
      visit_direction == "partner_to_china" ~ "Partner inbound visit",
      visit_direction == "third_party_meeting" ~ "Third-party meeting",
      TRUE ~ NA_character_)) %>%
    mutate(category_4 = case_when(
      is.na(category_4) & event_category_en != "Remote talk / virtual meeting" &
        str_detect(tolower(event_name), "to china|visits china|in china") ~ "Partner inbound visit",
      is.na(category_4) & event_category_en != "Remote talk / virtual meeting" &
        str_detect(tolower(event_name), "state visit to|official visit to|visit to ") ~ "Chinese outbound visit",
      TRUE ~ category_4))
}
visits <- visits %>% classify_visit_4() %>% filter(!is.na(category_4))
cat(sprintf("leader-visit events: %d\n", nrow(visits)))

post_months <- c(0, 1, 2, 3, 6, 12)
compute <- function(vis) {
  res <- list()
  for (db in unique(sc$db)) {
    db_sc <- sc %>% filter(db == !!db)
    for (cty in unique(vis$country_en)) {
      cty_ev <- vis %>% filter(country_en == cty)
      cty_sc <- db_sc %>% filter(country == cty)
      if (nrow(cty_ev) == 0 || nrow(cty_sc) == 0) next
      for (i in seq_len(nrow(cty_ev))) {
        ed <- cty_ev$event_date_ym[i]
        pre <- cty_sc %>% filter(month >= ed %m-% months(3), month < ed)
        bl <- mean(pre$value, na.rm = TRUE)
        if (is.na(bl)) next
        for (pm in post_months) {
          post <- cty_sc %>% filter(month == ed %m+% months(pm))
          if (nrow(post) > 0 && !is.na(post$value[1])) {
            res[[length(res) + 1]] <- tibble(db = db, category_4 = cty_ev$category_4[i],
              post_month = pm, shock = post$value[1] - bl)
          }
        }
      }
    }
  }
  bind_rows(res)
}
summ <- function(out) {
  out %>% filter(post_month == 0) %>% group_by(db, category_4) %>%
    summarise(mean = mean(shock, na.rm = TRUE), sd = sd(shock, na.rm = TRUE), n = n(),
              se = sd / sqrt(n), ci_lo = mean - 1.96 * se, ci_hi = mean + 1.96 * se, .groups = "drop")
}

full <- summ(compute(visits)) %>% mutate(regime = "full")
tr_ev <- visits %>% filter(event_date_ym <= CUTOFF)
trunc <- summ(compute(tr_ev)) %>% mutate(regime = "trunc")

both <- bind_rows(full, trunc) %>% arrange(db, category_4, regime)
write_csv(both, file.path(OUTDIR, "m5_visits_full_vs_trunc.csv"))

cat("\n== BEFORE (full, archive) vs AFTER (trunc, ICEWS events <= 2023-04) ==\n")
for (d in c("GDELT", "ICEWS")) {
  cat(sprintf("-- %s --\n", d))
  print(as.data.frame(both %>% filter(db == d) %>% select(regime, category_4, mean, ci_lo, ci_hi, n)), row.names = FALSE)
}
# filled-segment check: ICEWS events after cutoff have shock exactly 0?
post_ev <- visits %>% filter(event_date_ym > CUTOFF)
ice_sc <- sc %>% filter(db == "ICEWS")
zs <- compute(post_ev) %>% filter(db == "ICEWS", post_month == 0)
cat(sprintf("\nICEWS events in filled segment: %d; post_month=0 shocks all zero: %s\n",
            nrow(post_ev), ifelse(nrow(zs) == 0 || all(abs(zs$shock) < 1e-9), "YES", "NO"))
)
cat("saved m5_visits_full_vs_trunc.csv\n")
