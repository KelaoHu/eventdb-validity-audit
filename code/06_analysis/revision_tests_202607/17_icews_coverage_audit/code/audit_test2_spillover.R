# audit_test2_spillover.R — 第三方溢出检验：全期复制 vs 截断(≤2023-04) 对照

library(tidyverse); library(lubridate); library(fixest)
set.seed(20260716)
SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data"
OUT <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/17_ICEWS覆盖期审计/results"
CUTOFF <- as.Date("2023-04-01")
NPERM <- 1000

nodes0 <- read_csv(file.path(SD, "us_china_nodes.csv"), show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  mutate(node_ym = ymd(paste0(node_date, "-01")))
sc0 <- read_csv(file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"), show_col_types = FALSE, locale = locale(encoding = "UTF-8"))

run_mode <- function(sc, nodes, mode_label) {
  neg_nodes <- nodes %>% filter(node_valence == "negative") %>% pull(node_ym)
  pos_nodes <- nodes %>% filter(node_valence == "positive") %>% pull(node_ym)
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
  # Part A（节点层）
  partA <- list()
  for (dbn in c("GDELT", "ICEWS")) {
    sh <- shock_fn[[dbn]](nodes$node_ym) %>%
      left_join(nodes %>% select(node_ym, node_valence), by = c("node_date" = "node_ym"))
    dneg <- sh %>% filter(node_valence == "negative")
    f1 <- feols(avg_shock ~ 1, data = dneg, cluster = ~node_date)
    partA[[dbn]] <- tibble(db = dbn, neg_mean = mean(dneg$avg_shock), neg_mean_p = pvalue(f1)[1],
                           n_country_node = nrow(sh), n_neg_nodes = length(neg_nodes))
  }
  # Part C（置换，主推断）
  all_months <- sort(unique(sc$month))
  cand_months <- setdiff(all_months, nodes$node_ym)
  obs <- sapply(c("GDELT", "ICEWS"), function(dbn) mean(shock_fn[[dbn]](neg_nodes)$avg_shock))
  perm_sum <- list()
  for (dbn in c("GDELT", "ICEWS")) {
    pb <- numeric(NPERM)
    for (r in 1:NPERM) pb[r] <- mean(shock_fn[[dbn]](sample(cand_months, length(neg_nodes)))$avg_shock)
    p_one <- (1 + sum(pb <= obs[dbn])) / (NPERM + 1)
    p_two <- (1 + sum(abs(pb) >= abs(obs[dbn]))) / (NPERM + 1)
    perm_sum[[dbn]] <- tibble(db = dbn, obs = obs[dbn], perm_mean = mean(pb),
                              perm_p_oneside_neg = p_one, perm_p_twoside = p_two, n_neg_nodes = length(neg_nodes))
    cat(sprintf("[%s] %s: obs=%.4f perm_one_p=%.4f perm_two_p=%.4f (neg_nodes=%d)\n",
                mode_label, dbn, obs[dbn], p_one, p_two, length(neg_nodes)))
  }
  list(A = bind_rows(partA) %>% mutate(variant = mode_label),
       C = bind_rows(perm_sum) %>% mutate(variant = mode_label))
}

r_full  <- run_mode(sc0, nodes0, "full")
r_trunc <- run_mode(sc0 %>% filter(month <= CUTOFF),
                    nodes0 %>% filter(node_ym <= CUTOFF), "trunc")
write_csv(bind_rows(r_full$A, r_trunc$A), file.path(OUT, "test2_partA_full_vs_trunc.csv"))
write_csv(bind_rows(r_full$C, r_trunc$C), file.path(OUT, "test2_permutation_full_vs_trunc.csv"))
print(bind_rows(r_full$C, r_trunc$C), width = Inf)
cat("Done audit test2.\n")
