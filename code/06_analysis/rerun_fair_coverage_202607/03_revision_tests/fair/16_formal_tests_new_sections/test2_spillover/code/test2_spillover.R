# 检验2：中美负面关系事件对第三国对华政治分数的溢出——显著性检验

library(tidyverse); library(lubridate); library(fixest)
set.seed(20260716)

SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"
OUT <- "../results"; dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

nodes <- read_csv(file.path(SD, "us_china_nodes.csv"), show_col_types = FALSE,
                  locale = locale(encoding = "UTF-8")) %>%
  mutate(node_ym = ymd(paste0(node_date, "-01")))
sc <- read_csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), show_col_types = FALSE,
               locale = locale(encoding = "UTF-8"))
events <- read_csv(file.path(SD, "events_713.csv"), show_col_types = FALSE,
                   locale = locale(encoding = "UTF-8")) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")))

neg_nodes <- nodes %>% filter(node_valence == "negative") %>% pull(node_ym)
pos_nodes <- nodes %>% filter(node_valence == "positive") %>% pull(node_ym)
cat(sprintf("Nodes: %d negative, %d positive\n", length(neg_nodes), length(pos_nodes)))

# ---- M8 口径 shock 的快速构造器：shock(c, n) = mean(value[t..t+6]) - mean(value[t-3..t-1]) ----
mk_shock_fn <- function(dbn) {
  d <- sc %>% filter(db == dbn, country != "United States") %>% arrange(country, month)
  cty <- sort(unique(d$country)); mth <- sort(unique(d$month))
  V <- matrix(NA_real_, length(cty), length(mth), dimnames = list(cty, as.character(mth)))
  V[cbind(match(d$country, cty), match(as.character(d$month), as.character(mth)))] <- d$value
  BL <- matrix(NA_real_, nrow(V), ncol(V), dimnames = dimnames(V))
  for (j in 4:ncol(V)) BL[, j] <- rowMeans(V[, (j - 3):(j - 1), drop = FALSE], na.rm = TRUE)
  function(node_dates) {
    js <- match(as.character(node_dates), colnames(V))
    out <- list()
    for (k in seq_along(js)) {
      j <- js[k]; if (is.na(j)) next
      jj <- j:min(j + 6, ncol(V))
      shock <- rowMeans(V[, jj, drop = FALSE], na.rm = TRUE) - BL[, j]
      ok <- !is.na(shock) & !is.nan(shock)
      out[[k]] <- tibble(country = rownames(V)[ok], avg_shock = shock[ok], node_date = node_dates[k])
    }
    bind_rows(out)
  }
}
shock_fn <- setNames(lapply(c("GDELT", "ICEWS"), mk_shock_fn), c("GDELT", "ICEWS"))

# ---------- A. 事件-国家层面回归 ----------
partA <- list()
for (dbn in c("GDELT", "ICEWS")) {
  sh <- shock_fn[[dbn]](nodes$node_ym) %>%
    left_join(nodes %>% select(node_ym, node_valence), by = c("node_date" = "node_ym"))
  # 注：fixest 对 y ~ 1 | fe 不报告截距（coef 返回 NULL），故均值检验用无 FE 回归，聚类到节点
  f0 <- feols(avg_shock ~ 1, data = sh, cluster = ~node_date)   # 全部节点混合
  dneg <- sh %>% filter(node_valence == "negative")
  f1 <- feols(avg_shock ~ 1, data = dneg, cluster = ~node_date) # 负面节点 vs 0
  f2 <- feols(avg_shock ~ I(node_valence == "negative") | country, data = sh, cluster = ~node_date)
  partA[[dbn]] <- tibble(
    db = dbn,
    pooled_mean = coef(f0)[1], pooled_se = se(f0)[1], pooled_p = pvalue(f0)[1],
    neg_mean = mean(dneg$avg_shock), neg_mean_se = se(f1)[1], neg_mean_p = pvalue(f1)[1],
    pos_mean = mean((sh %>% filter(node_valence == "positive"))$avg_shock),
    diff_neg_vs_pos = coef(f2)[1], diff_se = se(f2)[1], diff_p = pvalue(f2)[1],
    n_country_node = nrow(sh), n_nodes = n_distinct(sh$node_date), n_neg_nodes = length(neg_nodes))
  write_csv(sh, file.path(OUT, sprintf("test2_shocks_country_node_%s.csv", dbn)))
}
tabA <- bind_rows(partA); write_csv(tabA, file.path(OUT, "test2_partA_nodelevel.csv"))
print(tabA, width = Inf)

# ---------- B. 月度面板局部投影（Country FE + Year FE，降级设定） ----------
own_ev <- events %>%
  filter(event_type_original != "leader_visit", impact %in% c("positive", "negative")) %>%
  group_by(country_en, event_date_ym) %>%
  summarise(own_neg = any(impact == "negative"), own_pos = any(impact == "positive"), .groups = "drop")

partB <- list()
for (dbn in c("GDELT", "ICEWS")) {
  panel <- sc %>% filter(db == dbn, country != "United States") %>%
    select(country, month, value) %>%
    mutate(neg_node = as.numeric(month %in% neg_nodes), pos_node = as.numeric(month %in% pos_nodes),
           year = year(month)) %>%
    left_join(own_ev, by = c("country" = "country_en", "month" = "event_date_ym")) %>%
    mutate(own_neg = as.numeric(replace_na(own_neg, FALSE)), own_pos = as.numeric(replace_na(own_pos, FALSE))) %>%
    arrange(country, month) %>% group_by(country) %>%
    mutate(l1 = lag(value, 1), l2 = lag(value, 2), l3 = lag(value, 3),
           bl = rowMeans(cbind(l1, l2, l3), na.rm = TRUE)) %>% ungroup()
  for (h in 0:6) {
    d <- panel %>% group_by(country) %>% mutate(leadv = lead(value, h)) %>% ungroup() %>%
      mutate(y = leadv - bl) %>% filter(!is.na(y), !is.nan(y))
    fit <- feols(y ~ neg_node + pos_node + own_neg + own_pos | country + year,
                 data = d, cluster = ~country + month)
    ct <- coeftable(fit)
    partB[[length(partB) + 1]] <- tibble(
      db = dbn, h = h,
      beta_neg_node = ct["neg_node", "Estimate"], se_neg = ct["neg_node", "Std. Error"],
      p_neg = ct["neg_node", "Pr(>|t|)"],
      beta_pos_node = ct["pos_node", "Estimate"], se_pos = ct["pos_node", "Std. Error"],
      p_pos = ct["pos_node", "Pr(>|t|)"],
      n_obs = nobs(fit), n_countries = n_distinct(d$country))
  }
}
tabB <- bind_rows(partB); write_csv(tabB, file.path(OUT, "test2_partB_panel_lp.csv"))
print(tabB, width = Inf)

# ---------- C. 事件时间置换安慰剂（主推断，1000 次） ----------
NPERM <- 1000
all_months <- sort(unique(sc$month))
cand_months <- setdiff(all_months, nodes$node_ym)

obs <- sapply(c("GDELT", "ICEWS"), function(dbn) mean(shock_fn[[dbn]](neg_nodes)$avg_shock))
cat(sprintf("\nObserved negative-node mean spillover: GDELT=%.4f, ICEWS=%.4f\n", obs["GDELT"], obs["ICEWS"]))

perm_out <- list(); perm_sum <- list()
for (dbn in c("GDELT", "ICEWS")) {
  pb <- numeric(NPERM)
  for (r in 1:NPERM) pb[r] <- mean(shock_fn[[dbn]](sample(cand_months, length(neg_nodes)))$avg_shock)
  p_one <- (1 + sum(pb <= obs[dbn])) / (NPERM + 1)
  p_two <- (1 + sum(abs(pb) >= abs(obs[dbn]))) / (NPERM + 1)
  perm_out[[dbn]] <- tibble(db = dbn, perm = 1:NPERM, spill_perm = pb)
  perm_sum[[dbn]] <- tibble(db = dbn, obs = obs[dbn], perm_mean = mean(pb), perm_sd = sd(pb),
                            perm_q025 = quantile(pb, .025), perm_q975 = quantile(pb, .975),
                            perm_p_oneside_neg = p_one, perm_p_twoside = p_two,
                            n_perm = NPERM, n_neg_nodes = length(neg_nodes))
  cat(sprintf("%s: perm mean=%.4f sd=%.4f one-sided p=%.4f two-sided p=%.4f\n",
              dbn, mean(pb), sd(pb), p_one, p_two))
}
write_csv(bind_rows(perm_out), file.path(OUT, "test2_permutation_draws.csv"))
tabp <- bind_rows(perm_sum); write_csv(tabp, file.path(OUT, "test2_permutation_summary.csv"))
print(tabp, width = Inf)
cat("Done test2.\n")
