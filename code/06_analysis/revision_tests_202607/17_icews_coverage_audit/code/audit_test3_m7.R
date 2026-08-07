# audit_test3_m7.R — M7 信任非对称 + Wald 对称性检验：全期复制 vs 截断(≤2023-04) 对照

library(tidyverse); library(lubridate); library(fixest)
SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/17_ICEWS覆盖期审计/results"
CUTOFF <- as.Date("2023-04-01")

events <- read_csv(file.path(SD, "events_713.csv"), show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")))
sc0 <- read_csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), show_col_types = FALSE, locale = locale(encoding = "UTF-8"))
non_leader <- events %>% filter(event_type_original != "leader_visit", impact %in% c("positive", "negative"))

# ---- Part 1: M7 描述性均值（07 模块口径：baseline t-3..-1, h=0/1/3/6）----
m7_means <- function(sc, mode_label) {
  res <- list()
  for (dbn in unique(sc$db)) {
    db_sc <- sc %>% filter(db == dbn)
    for (cty in unique(non_leader$country_en)) {
      cty_ev <- non_leader %>% filter(country_en == cty); cty_sc <- db_sc %>% filter(country == cty)
      if (nrow(cty_ev) == 0 || nrow(cty_sc) == 0) next
      for (i in seq_len(nrow(cty_ev))) {
        ed <- cty_ev$event_date_ym[i]
        pre <- cty_sc %>% filter(month >= ed %m-% months(3), month < ed)
        bl <- mean(pre$value, na.rm = TRUE); if (is.na(bl)) next
        for (pm in c(0, 1, 3, 6)) {
          post <- cty_sc %>% filter(month == ed %m+% months(pm))
          if (nrow(post) > 0 && !is.na(post$value[1]))
            res[[length(res) + 1]] <- tibble(db = dbn, country = cty, valence = cty_ev$impact[i],
                                             post_month = pm, shock = post$value[1] - bl)
        }
      }
    }
  }
  bind_rows(res) %>% group_by(db, valence, post_month) %>%
    summarise(mean_shock = mean(shock, na.rm = TRUE), n = n(), .groups = "drop") %>%
    mutate(variant = mode_label)
}

# ---- Part 2: Wald 对称性（test3 口径：Country+Month FE，change 设定）----
wald_sym <- function(sc, mode_label) {
  ev <- events %>%
    filter(event_type_original != "leader_visit", impact %in% c("positive", "negative")) %>%
    group_by(country_en, event_date_ym) %>%
    summarise(neg = any(impact == "negative"), pos = any(impact == "positive"), .groups = "drop")
  rows <- list()
  for (dbn in c("GDELT", "ICEWS")) {
    panel <- sc %>% filter(db == dbn) %>%
      select(country, month, value) %>%
      left_join(ev, by = c("country" = "country_en", "month" = "event_date_ym")) %>%
      mutate(neg = as.numeric(replace_na(neg, FALSE)), pos = as.numeric(replace_na(pos, FALSE))) %>%
      arrange(country, month) %>% group_by(country) %>%
      mutate(l1 = lag(value, 1), l2 = lag(value, 2), l3 = lag(value, 3),
             bl = rowMeans(cbind(l1, l2, l3), na.rm = TRUE)) %>% ungroup()
    for (h in 0:6) {
      d <- panel %>% group_by(country) %>% mutate(leadv = lead(value, h)) %>% ungroup() %>%
        mutate(y = leadv - bl) %>% filter(!is.na(y), !is.nan(y))
      fit <- feols(y ~ pos + neg | country + month, data = d, cluster = ~country + month)
      b <- coef(fit); V <- vcov(fit); ct <- coeftable(fit)
      R <- c(1, 1); stat <- as.numeric(t(R %*% b) %*% solve(R %*% V %*% R) %*% (R %*% b))
      rows[[length(rows) + 1]] <- tibble(
        variant = mode_label, db = dbn, spec = "change", h = h,
        beta_pos = b["pos"], p_pos_2side = ct["pos", "Pr(>|t|)"],
        beta_neg = b["neg"], p_neg_2side = ct["neg", "Pr(>|t|)"],
        wald_chi2_sym = stat, wald_p_sym = 1 - pchisq(stat, df = 1), n_obs = nobs(fit))
    }
  }
  bind_rows(rows)
}

modes <- list(full = sc0, trunc = sc0 %>% filter(month <= CUTOFF))
m7_all <- list(); wald_all <- list()
for (m in names(modes)) {
  m7_all[[m]] <- m7_means(modes[[m]], m)
  wald_all[[m]] <- wald_sym(modes[[m]], m)
}
m7_out <- bind_rows(m7_all) %>% select(variant, everything())
wald_out <- bind_rows(wald_all) %>% select(variant, everything())
write_csv(m7_out, file.path(OUT, "m7_asymmetry_full_vs_trunc.csv"))
write_csv(wald_out, file.path(OUT, "test3_wald_full_vs_trunc.csv"))
cat("== M7 描述性均值（h=0）==\n")
print(m7_out %>% filter(post_month == 0), n = 20)
cat("== Wald 对称性（h=0, change）==\n")
print(wald_out %>% filter(h == 0), n = 10)
cat("Done audit test3+m7.\n")
