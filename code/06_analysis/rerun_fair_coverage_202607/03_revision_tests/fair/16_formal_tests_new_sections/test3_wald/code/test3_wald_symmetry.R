# 检验3：正面 vs 负面事件 IRF 对称性的 Wald 检验

library(tidyverse); library(lubridate); library(fixest)
set.seed(20260716)

SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"
OUT <- "../results"; dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

events <- read_csv(file.path(SD, "events_713.csv"), show_col_types = FALSE,
                   locale = locale(encoding = "UTF-8")) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")))
sc <- read_csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), show_col_types = FALSE,
               locale = locale(encoding = "UTF-8"))

ev <- events %>%
  filter(event_type_original != "leader_visit", impact %in% c("positive", "negative")) %>%
  group_by(country_en, event_date_ym) %>%
  summarise(neg = any(impact == "negative"), pos = any(impact == "positive"), .groups = "drop")

main_rows <- list(); joint_rows <- list()
for (dbn in c("GDELT", "ICEWS")) {
  for (spec in c("change", "level")) {
    panel <- sc %>% filter(db == dbn) %>%
      select(country, month, value) %>%
      left_join(ev, by = c("country" = "country_en", "month" = "event_date_ym")) %>%
      mutate(neg = as.numeric(replace_na(neg, FALSE)), pos = as.numeric(replace_na(pos, FALSE))) %>%
      arrange(country, month) %>% group_by(country) %>%
      mutate(l1 = lag(value, 1), l2 = lag(value, 2), l3 = lag(value, 3),
             bl = rowMeans(cbind(l1, l2, l3), na.rm = TRUE)) %>% ungroup()

    stacked <- list()
    for (h in 0:6) {
      d <- panel %>% group_by(country) %>% mutate(leadv = lead(value, h)) %>% ungroup()
      d <- if (spec == "change") d %>% mutate(y = leadv - bl) else d %>% mutate(y = leadv)
      d <- d %>% filter(!is.na(y), !is.nan(y))
      fit <- feols(y ~ pos + neg | country + month, data = d, cluster = ~country + month)
      b <- coef(fit); V <- vcov(fit); ct <- coeftable(fit)
      R <- c(1, 1); stat <- as.numeric(t(R %*% b) %*% solve(R %*% V %*% R) %*% (R %*% b))
      p_sym <- 1 - pchisq(stat, df = 1)
      t_pos <- b["pos"] / sqrt(V["pos", "pos"])
      main_rows[[length(main_rows) + 1]] <- tibble(
        db = dbn, spec = spec, h = h,
        beta_pos = b["pos"], se_pos = ct["pos", "Std. Error"], p_pos_2side = ct["pos", "Pr(>|t|)"],
        p_pos_1side_neg = pnorm(t_pos),
        beta_neg = b["neg"], se_neg = ct["neg", "Std. Error"], p_neg_2side = ct["neg", "Pr(>|t|)"],
        wald_chi2_sym = stat, wald_p_sym = p_sym,
        ratio_abs = abs(b["pos"] / b["neg"]),
        n_obs = nobs(fit), n_pos_exposed = sum(d$pos), n_neg_exposed = sum(d$neg))
      if (spec == "change" && h >= 3) {
        stacked[[length(stacked) + 1]] <- d %>%
          transmute(unit = paste(country, month), country = country, month = month,
                    hz = factor(h), y = y, pos = pos, neg = neg)
      }
    }
    if (spec == "change") {
      ds <- bind_rows(stacked) %>%
        mutate(unit = factor(unit), country_h = paste(country, hz), month_h = paste(month, hz))
      fit_s <- feols(y ~ i(hz, pos) + i(hz, neg) | country_h + month_h, data = ds, cluster = ~unit)
      wj <- wald(fit_s, keep = "pos")
      joint_rows[[length(joint_rows) + 1]] <- tibble(
        db = dbn, spec = spec, horizons = "3:6",
        joint_F = wj$stat, joint_p = wj$p, n_obs = nobs(fit_s))
      cat(sprintf("%s/%s stacked joint Wald (pos h=3..6 = 0): F=%.3f p=%.4f\n",
                  dbn, spec, wj$stat, wj$p))
      print(coeftable(fit_s))
    }
  }
}

tab_main <- bind_rows(main_rows); tab_joint <- bind_rows(joint_rows)
write_csv(tab_main, file.path(OUT, "test3_wald_symmetry.csv"))
write_csv(tab_joint, file.path(OUT, "test3_joint_pos_h3_6.csv"))
print(tab_main %>% select(db, spec, h, beta_pos, p_pos_2side, p_pos_1side_neg,
                          beta_neg, p_neg_2side, wald_chi2_sym, wald_p_sym, ratio_abs), n = 28)
print(tab_joint)
cat("Done test3.\n")
