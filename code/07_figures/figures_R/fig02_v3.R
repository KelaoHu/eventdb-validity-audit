# fig02_v3.R — 图 2「机器抓行为、专家判烈度」

suppressMessages({
  source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R")
  library(stringr); library(lubridate)
})

ROOT_D <- "C:/Users/胡克劳/Desktop/311工程数据"
TAB_S4 <- file.path(ROOT_D, "05_文档/附录数据表/Table_S4_1R_Hitrate_comparison.csv")
FAIR_HIT <- file.path(ROOT_D, "03_检验与分析套件/修订补充检验_202607/17_ICEWS覆盖期审计/results/hitrate_coop_conflict_fair_era.csv")
ES_DIR_FAIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"
M1_FAIR_QA <- file.path(ROOT_D, "03_检验与分析套件/重跑_公平覆盖期_202607/03_修订检验/fair/11_M1事件研究显著性补算/results/m1_irf_significance.csv")
OUT <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/fig02_编码哲学/output/fig02"
stopifnot(file.exists(TAB_S4), file.exists(FAIR_HIT), file.exists(M1_FAIR_QA), dir.exists(ES_DIR_FAIR))

# ================= Panel a 数据 =================
h1 <- read_csv(TAB_S4, show_col_types = FALSE) %>%
  filter(Sample == "Full sample (with extrapolated segments)",
         `Event category` %in% c("Cooperation", "Conflict/Shock")) %>%
  transmute(category = `Event category`, db = Database,
            pct = as.numeric(str_match(`Strict window W_strict`, "（([0-9.]+)%）")[, 2]))

h2 <- read_csv(FAIR_HIT, show_col_types = FALSE) %>%
  filter(regime == "fair", window == "W_strict", db %in% c("ICEWS", "Phoenix")) %>%
  transmute(category = recode(group, Conflict = "Conflict/Shock"),
            db, pct = hit_rate * 100)

hit <- bind_rows(h1 %>% filter(db %in% c("GDELT", "Tsinghua")), h2) %>%
  mutate(category = factor(category, levels = c("Cooperation", "Conflict/Shock")),
         db = factor(db, levels = names(DB_COLORS)))
stopifnot(nrow(hit) == 8, !any(is.na(hit$pct)))

# QA 闸门（±0.5pp）
qa_hit <- function(db0, cat0, v) {
  x <- hit$pct[hit$db == db0 & hit$category == cat0]
  stopifnot(abs(x - v) < 0.5)
  cat(sprintf("[QA] hitrate %s / %s = %.1f (期望 %.1f) OK\n", db0, cat0, x, v))
}
qa_hit("GDELT", "Cooperation", 67.5)
qa_hit("Tsinghua", "Cooperation", 51.3)
qa_hit("Tsinghua", "Conflict/Shock", 75.8)

# ================= Panel a 图形 =================
YOFF <- c(GDELT = 0.15, Phoenix = 0.07, ICEWS = -0.07, Tsinghua = -0.15)
hit <- hit %>% mutate(y = as.numeric(category) + YOFF[as.character(db)],
                      yl = as.numeric(category) + YOFF[as.character(db)] * 3.0)
seg_a <- hit %>% group_by(category) %>%
  summarise(xmin = min(pct), xmax = max(pct), y = as.numeric(category)[1], .groups = "drop")

pa <- ggplot(hit) +
  geom_segment(data = seg_a, aes(x = xmin, xend = xmax, y = y, yend = y),
               colour = "#D9D9D9", linewidth = 1.6, lineend = "round") +
  geom_point(aes(x = pct, y = y, colour = db), size = PT_MAIN) +
  geom_text(aes(x = pct, y = yl, label = sprintf("%.1f", pct), colour = db),
            size = 2.4, family = "Arial", fontface = "bold", show.legend = FALSE) +
  scale_colour_manual(values = DB_COLORS, labels = DB_LABELS) +
  scale_y_continuous(breaks = 1:2, labels = c("Cooperation", "Conflict / Shock"),
                     limits = c(0.42, 2.5), expand = c(0, 0)) +
  scale_x_continuous(limits = c(47, 80), breaks = seq(50, 80, 10),
                     expand = expansion(mult = c(0.01, 0.01))) +
  labs(x = "Hit rate within strict window (%)", y = NULL, tag = "a") +
  annotate("text", x = 79.5, y = 0.52, label = "Grey bar: range across four databases",
           hjust = 1, size = 1.9, family = "Arial", colour = "#999999") +
  theme_nature() +
  theme(legend.position = "top",
        legend.text = element_text(size = SZ_TICK),
        axis.text.y = element_text(size = SZ_AXIST, face = "bold"))

# ================= Panel b 数据：fair 口径重算逐事件 shock =================
ev <- read_csv(file.path(ES_DIR_FAIR, "events_712.csv"),
               show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  filter(event_type_original != "leader_visit", impact %in% c("positive", "negative")) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")),
         event_id = paste(country_en, event_date, event_name, sep = "|"))

sc <- read_csv(file.path(ES_DIR_FAIR, "scores_v1_4DB_2019.csv"),
               show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  mutate(month = ymd(month))

H <- c(0, 1, 3, 6, 12)
shocks <- list()
for (dbi in c("GDELT", "ICEWS", "Phoenix", "Tsinghua")) {
  d <- sc %>% filter(db == dbi) %>% select(country, month, value)
  for (i in seq_len(nrow(ev))) {
    e <- ev[i, ]; ed <- e$event_date_ym
    s <- d %>% filter(country == e$country_en) %>% arrange(month)
    if (nrow(s) == 0) next
    pre <- s %>% filter(month >= ed %m-% months(12), month <= ed %m-% months(7))
    if (nrow(pre) < 4) next
    bl <- mean(pre$value, na.rm = TRUE); if (is.na(bl)) next
    for (h in H) {
      post <- s %>% filter(month == ed %m+% months(h))
      if (nrow(post) > 0 && !is.na(post$value[1]))
        shocks[[length(shocks) + 1]] <- tibble(db = dbi, direction = e$impact, h = h,
                                               shock = post$value[1] - bl)
    }
  }
}
sh <- bind_rows(shocks)
cat(sprintf("[fair] 重算 event-h 观测：%d\n", nrow(sh)))

sig <- read_csv(M1_FAIR_QA, show_col_types = FALSE)
chk <- sh %>% group_by(db, direction, h) %>%
  summarise(mean_shock = mean(shock), .groups = "drop") %>%
  left_join(sig %>% select(db, direction, h, response), by = c("db", "direction", "h")) %>%
  mutate(diff = abs(mean_shock - response))
stopifnot(all(chk$diff < 0.01, na.rm = TRUE))
cat("[QA] M1-fair 重算与 11_M1 存档全部一致（容差 0.01）\n")

# QA 闸门（±0.05）
qa_irf <- function(db0, dir0, h0, v) {
  x <- sig$response[sig$db == db0 & sig$direction == dir0 & sig$h == h0]
  stopifnot(abs(x - v) < 0.05)
  cat(sprintf("[QA] IRF %s %s h=%d = %.2f (期望 %.2f) OK\n", db0, dir0, h0, x, v))
}
qa_irf("Phoenix", "negative", 0, -1.87)
qa_irf("Phoenix", "positive", 0, 0.43)

# ================= Panel b 图形 =================
LAB_NEG <- "Negative events"; LAB_POS <- "Positive events"
irf <- sig %>%
  mutate(sigf = p_boot < 0.05,
         direction = factor(direction, levels = c("negative", "positive"),
                            labels = c(LAB_NEG, LAB_POS)),
         db = factor(db, levels = names(DB_COLORS), labels = DB_LABELS))

segs <- irf %>% arrange(db, direction, h) %>%
  group_by(db, direction) %>%
  mutate(h2 = lead(h), r2 = lead(response), sig2 = lead(sigf)) %>%
  filter(!is.na(h2)) %>% mutate(both_sig = sigf & sig2) %>% ungroup()

DIR_COLS <- setNames(c(COL_NEG, COL_POS), c(LAB_NEG, LAB_POS))

# 各分面事件数（h=0 有效观测口径）
nlab <- sh %>% filter(h == 0) %>% group_by(db) %>%
  summarise(lab = sprintf("n = %d neg / %d pos",
                          sum(direction == "negative"), sum(direction == "positive")),
            .groups = "drop") %>%
  mutate(db = factor(db, levels = names(DB_COLORS), labels = DB_LABELS))
cat("[n] per facet:\n"); print(as.data.frame(nlab))

pb <- ggplot(irf, aes(x = h)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4, colour = COL_REF) +
  geom_text(data = nlab, aes(x = -Inf, y = -Inf, label = lab), hjust = -0.04, vjust = -0.9,
            size = 1.9, family = "Arial", colour = "#777777", inherit.aes = FALSE) +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi, fill = direction, group = direction),
              alpha = 0.13, colour = NA) +
  geom_line(aes(y = response, colour = direction, group = direction),
            linetype = "dashed", linewidth = 0.4, alpha = 0.55) +
  geom_segment(data = segs %>% filter(both_sig),
               aes(x = h, xend = h2, y = response, yend = r2, colour = direction),
               linewidth = 0.8) +
  geom_point(aes(y = response, colour = direction, shape = sigf), size = 1.7, stroke = 0.7) +
  scale_colour_manual(values = DIR_COLS) +
  scale_fill_manual(values = DIR_COLS) +
  scale_shape_manual(values = c("TRUE" = 16, "FALSE" = 1), guide = "none") +
  scale_x_continuous(breaks = H, minor_breaks = NULL) +
  facet_wrap(~db, ncol = 4) +
  labs(x = "Months after event (h)", y = "Mean response (score units)", tag = "b") +
  theme_nature() +
  theme(legend.position = "top",
        axis.text = element_text(size = 6.5),
        strip.text = element_text(size = SZ_AXIST, face = "bold"))

# ================= 合成与输出 =================
p <- pa / pb + plot_layout(heights = c(1, 1.15))
save_pub(p, OUT, 180, 130)
cat("fig02 done; QA passed (hitrate 67.5/51.3/75.8; IRF Phoenix -1.87/+0.43; M1-fair consistent)\n")
