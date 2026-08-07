# 05b_phone_irf_by_group.R

rm(list = ls())
library(data.table); library(ggplot2)

PPML_ROOT  <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
EVENTS_CSV <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data/events_713.csv"
RES_DIR    <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/05_远程通话混淆控制/results"
FIG_DIR    <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/05_远程通话混淆控制/figures"
dir.create(RES_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

shift_month <- function(d, k) {
  y <- as.integer(format(d, "%Y")); m <- as.integer(format(d, "%m"))
  m2 <- m + k; y2 <- y + (m2 - 1L) %/% 12L; m3 <- (m2 - 1L) %% 12L + 1L
  as.Date(sprintf("%04d-%02d-01", y2, m3))
}

# ---- 面板 ----
panel <- fread(file.path(PPML_ROOT, "data/panel_clean.csv"), encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, YearMonth := as.Date(month)]
panel <- panel[!is.na(Trade_Imports)]
panel[, `:=`(lnImp = log(Trade_Imports), lnTot = log(Trade_Total))]
panel[Trade_Imports <= 0, lnImp := NA_real_]
panel[Trade_Total   <= 0, lnTot := NA_real_]
setkey(panel, Country, YearMonth)

# ---- 事件 ----
ev <- fread(EVENTS_CSV, encoding = "UTF-8")
setnames(ev, sub("^\ufeff", "", names(ev)))
ev[, impact := tolower(impact)]
rt <- ev[grepl("Remote talk", event_category_en),
         .(Country = country_en, ev_ym = as.Date(paste0(event_date, "-01")), event_name)]
neg <- ev[event_type_original != "leader_visit" & impact == "negative",
          .(Country = country_en, neg_ym = as.Date(paste0(event_date, "-01")))]

# ---- 分组 ----
# 主分组：±1月内有同国负面事件
rt[, n_neg_pm1 := sapply(seq_len(.N), function(i)
  sum(neg$Country == Country[i] & neg$neg_ym >= shift_month(ev_ym[i], -1L) &
        neg$neg_ym <= shift_month(ev_ym[i], 1L)))]
rt[, n_neg_same := sapply(seq_len(.N), function(i)
  sum(neg$Country == Country[i] & neg$neg_ym == ev_ym[i]))]
rt[, group_draft_pm1  := ifelse(n_neg_pm1 > 0, "High-confound (neg event within +/-1m)",
                                "Low-confound (no concurrent neg event)")]
rt[, group_draft_same := ifelse(n_neg_same > 0, "High-confound", "Low-confound")]
# 辅助分组：疫情危机窗口
rt[, in_covid_window := ev_ym >= as.Date("2020-01-01") & ev_ym <= as.Date("2021-12-01")]
rt[, group_covid := ifelse(in_covid_window,
                           "Crisis-window calls (2020.01-2021.12)",
                           "Non-crisis-window calls")]

cat("远程通话事件数:", nrow(rt), "\n")
print(rt[, .(Country, ev_ym, n_neg_same, n_neg_pm1, in_covid_window)])

# 剔除事件月超出面板范围的事件（基准期或事件月不在面板内）
panel_countries <- unique(panel$Country)
rt[, usable := Country %in% panel_countries &
       shift_month(ev_ym, -3L) >= min(panel$YearMonth) &
       ev_ym <= max(panel$YearMonth)]
cat("可用于事件研究的事件数:", sum(rt$usable), "\n")
rt_u <- rt[usable == TRUE]

# ---- 事件研究 IRF ----
get_series <- function(cty) panel[Country == cty, .(YearMonth, lnImp, lnTot)]

irf_list <- list()
for (i in seq_len(nrow(rt_u))) {
  s <- get_series(rt_u$Country[i])
  e <- rt_u$ev_ym[i]
  base <- s[YearMonth >= shift_month(e, -3L) & YearMonth <= shift_month(e, -1L)]
  bl_imp <- mean(base$lnImp, na.rm = TRUE); bl_tot <- mean(base$lnTot, na.rm = TRUE)
  for (h in -6:6) {
    row <- s[YearMonth == shift_month(e, h)]
    irf_list[[length(irf_list) + 1]] <- data.table(
      Country = rt_u$Country[i], ev_ym = e, h = h,
      irf_imports = if (nrow(row) == 1 && !is.na(bl_imp)) row$lnImp - bl_imp else NA_real_,
      irf_total   = if (nrow(row) == 1 && !is.na(bl_tot)) row$lnTot - bl_tot else NA_real_,
      group_draft_pm1 = rt_u$group_draft_pm1[i],
      group_covid     = rt_u$group_covid[i]
    )
  }
}
irf_ev <- rbindlist(irf_list)

# ---- 聚合函数 ----
agg_by_group <- function(dt, group_col, val_col) {
  ag <- dt[, .(mean = mean(get(val_col), na.rm = TRUE),
               se = sd(get(val_col), na.rm = TRUE) / sqrt(sum(!is.na(get(val_col)))),
               n = sum(!is.na(get(val_col)))),
           by = c(group_col, "h")]
  setnames(ag, group_col, "group")
  ag[, value := val_col]
  return(ag)
}
# 组间差异检验（双侧 t，不等方差）
diff_test <- function(dt, group_col, val_col) {
  gs <- unique(dt[[group_col]])
  if (length(gs) < 2) return(NULL)
  rbindlist(lapply(sort(unique(dt$h)), function(hh) {
    a <- dt[get(group_col) == gs[1] & h == hh][[val_col]]
    b <- dt[get(group_col) == gs[2] & h == hh][[val_col]]
    a <- a[!is.na(a)]; b <- b[!is.na(b)]
    if (length(a) < 2 || length(b) < 2)
      return(data.table(h = hh, diff = NA_real_, t = NA_real_, pvalue = NA_real_))
    tt <- t.test(a, b)
    data.table(h = hh, diff = mean(a) - mean(b), t = unname(tt$statistic),
               pvalue = tt$p.value)
  }))[, `:=`(value = val_col, grouping = group_col)]
}

res_all <- list()
for (gc in c("group_draft_pm1", "group_covid")) {
  for (vc in c("irf_imports", "irf_total")) {
    a <- agg_by_group(irf_ev, gc, vc)[, grouping := gc]
    d <- diff_test(irf_ev, gc, vc)
    res_all[[length(res_all) + 1]] <- a
    if (!is.null(d)) res_all[[length(res_all) + 1]] <-
      d[, .(group = "DIFF (group1 - group2)", h, mean = diff, se = NA_real_,
            n = NA_integer_, value, grouping, pvalue)]
  }
}
# 全体事件 IRF（参照）
for (vc in c("irf_imports", "irf_total")) {
  res_all[[length(res_all) + 1]] <-
    irf_ev[, .(mean = mean(get(vc), na.rm = TRUE),
               se = sd(get(vc), na.rm = TRUE) / sqrt(sum(!is.na(get(vc)))),
               n = sum(!is.na(get(vc)))), by = h
           ][, `:=`(group = "ALL remote-talk events", value = vc, grouping = "all")]
}
out <- rbindlist(res_all, fill = TRUE)
if (!"pvalue" %in% names(out)) out[, pvalue := NA_real_]

# 分组结构摘要行
grp_summary <- rbindlist(list(
  rt_u[, .(grouping = "group_draft_same", n_events = .N), by = .(group = group_draft_same)],
  rt_u[, .(grouping = "group_draft_pm1",  n_events = .N), by = .(group = group_draft_pm1)],
  rt_u[, .(grouping = "group_covid",      n_events = .N), by = .(group = group_covid)]
))[, `:=`(h = NA_integer_, mean = NA_real_, se = NA_real_, n = NA_integer_,
          value = "group_event_counts", pvalue = NA_real_)]
out <- rbind(out, grp_summary, fill = TRUE)

fwrite(out, file.path(RES_DIR, "phone_call_irf_by_group.csv"))
cat("\n✓ phone_call_irf_by_group.csv 已保存 (", nrow(out), " 行)\n")

# ---- 图：辅助分组（疫情窗口代理）+ 全体 ----
plot_dt <- out[grouping %in% c("group_covid", "all") & !is.na(h) &
               group != "DIFF (group1 - group2)"]
plot_dt[, outcome := ifelse(value == "irf_imports", "China's Imports", "Total Trade")]
plot_dt[, ci_lo := mean - 1.96 * se][, ci_hi := mean + 1.96 * se]
plot_dt[group == "ALL remote-talk events", group := "All 18 remote-talk events"]

p <- ggplot(plot_dt, aes(x = h, y = mean, color = group, fill = group)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = 0, linetype = "dotted", color = "grey50") +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.9) + geom_point(size = 1.6) +
  facet_wrap(~outcome, ncol = 2) +
  scale_x_continuous(breaks = -6:6) +
  labs(title = "Event-study IRF of trade around China-partner remote talks",
       subtitle = "Log deviation from pre-event baseline (mean of t-3 to t-1); 95% CI. Groups: crisis-window proxy for confounding.",
       x = "Months relative to remote talk (t = 0)", y = "Log deviation from baseline",
       color = NULL, fill = NULL) +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom", plot.title = element_text(size = 12))

ggsave(file.path(FIG_DIR, "phone_call_irf_groups.png"), p,
       width = 10, height = 5.5, dpi = 300)
cat("✓ phone_call_irf_groups.png 已保存\n")

# 打印关键结果
cat("\n[组间差异检验 - covid window, imports]\n")
print(out[grouping == "group_covid" & group == "DIFF (group1 - group2)" & value == "irf_imports"])
