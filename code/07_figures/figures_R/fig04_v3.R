# fig04_v3.R — 图 4「信号的成本与信任的坡度」（三面板）

suppressMessages({
  source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R")
})

ROOT <- "C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件/重跑_公平覆盖期_202607"
F_A <- file.path(ROOT, "02_事件研究套件/fair/05_领导人会晤效应与双边关系/code/results/direction_summary.csv")
F_B <- file.path(ROOT, "03_修订检验/fair/16_新增小节正式检验/test3_wald/results/test3_wald_symmetry.csv")
F_C <- file.path(ROOT, "03_修订检验/fair/16_新增小节正式检验/test1_alliance/results/test1_lp_interaction.csv")
OUT  <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/fig04_信号机制/output/fig04"

# ---------- Panel a 数据 ----------
da <- read_csv(F_A, show_col_types = FALSE, locale = locale(encoding = "UTF-8"))
cat_ord <- c("Chinese outbound visit", "Partner inbound visit",
             "Third-party meeting", "Remote talk")
cat_lab <- c("Chinese outbound\nvisit", "Partner inbound\nvisit",
             "Third-party\nmeeting", "Remote talk")
da <- da %>%
  mutate(category_4 = factor(category_4, levels = cat_ord, labels = cat_lab),
         ns = ci_lower < 0 & ci_upper > 0)
# 各类别 n（GDELT/ICEWS 序，与图例一致）写入轴标签
n_tab <- da %>% select(category_4, db, n) %>%
  tidyr::pivot_wider(names_from = db, values_from = n)
cat_lab2 <- setNames(
  paste0(cat_lab, "\n(n = ", n_tab$GDELT[match(cat_lab, n_tab$category_4)],
         " / ", n_tab$ICEWS[match(cat_lab, n_tab$category_4)], ")"),
  cat_lab)
# QA 闸门
qa <- function(db, cat, val, tol = 0.01)
  abs(da$mean[da$db == db & da$category_4 == cat] - val) < tol
stopifnot(
  qa("GDELT", cat_lab[1], 0.399), qa("GDELT", cat_lab[2], 0.369), qa("GDELT", cat_lab[3], 0.168),
  qa("ICEWS", cat_lab[1], 0.502), qa("ICEWS", cat_lab[2], 0.459), qa("ICEWS", cat_lab[3], 0.233))
da <- da %>% mutate(category_4 = factor(category_4, levels = cat_lab,
                                        labels = cat_lab2[cat_lab]))

pa <- ggplot(da, aes(category_4, mean, fill = db)) +
  geom_col(position = position_dodge(width = 0.72), width = 0.62, alpha = 0.92) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                position = position_dodge(width = 0.72), width = 0.22,
                linewidth = 0.4, colour = COL_INK) +
  geom_text(aes(y = ci_upper + 0.10, label = ifelse(ns, sprintf("%.2f n.s.", mean), sprintf("%.2f", mean)),
                colour = ns),
            position = position_dodge(width = 0.72),
            size = 2.2, family = "Arial", fontface = "bold", show.legend = FALSE) +
  scale_fill_manual(values = DB_COLORS[1:2], labels = DB_LABELS[1:2]) +
  scale_colour_manual(values = c(`TRUE` = COL_NS, `FALSE` = COL_INK), guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
  labs(x = NULL, y = "Mean bilateral score after event", tag = "a") +
  theme_nature() +
  theme(legend.position = "top",
        legend.justification = "right",
        legend.margin = margin(0, 0, -2, 0),
        axis.text.x = element_text(size = 6.2, lineheight = 0.9))

# ---------- Panel b 数据 ----------
db_ <- read_csv(F_B, show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  filter(spec == "change") %>%
  transmute(db, h,
            pos = beta_pos, pos_lo = beta_pos - 1.96 * se_pos, pos_hi = beta_pos + 1.96 * se_pos,
            neg = beta_neg, neg_lo = beta_neg - 1.96 * se_neg, neg_hi = beta_neg + 1.96 * se_neg,
            wald_p = wald_p_sym)
dbl <- bind_rows(
  db_ %>% transmute(db, h, dir = "Positive shock", beta = pos, lo = pos_lo, hi = pos_hi),
  db_ %>% transmute(db, h, dir = "Negative shock", beta = neg, lo = neg_lo, hi = neg_hi)) %>%
  mutate(dir = factor(dir, levels = c("Positive shock", "Negative shock")),
         db  = factor(db, levels = c("GDELT", "ICEWS")))
# QA 闸门
qb <- db_ %>% filter(h == 0)
stopifnot(
  abs(qb$neg[qb$db == "GDELT"] - (-0.428)) < 0.01, abs(qb$pos[qb$db == "GDELT"] - 0.260) < 0.01,
  abs(qb$neg[qb$db == "ICEWS"] - (-0.812)) < 0.01, abs(qb$pos[qb$db == "ICEWS"] - 0.309) < 0.01,
  abs(qb$wald_p[qb$db == "GDELT"] - 0.20) < 0.02, abs(qb$wald_p[qb$db == "ICEWS"] - 0.025) < 0.01)

p_lab <- qb %>% mutate(lab = ifelse(wald_p < 0.001, "Wald p < 0.001", sprintf("Wald p = %.3f", wald_p)))

pb <- ggplot(dbl, aes(h, beta, colour = dir, fill = dir)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4, colour = COL_REF) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.18, colour = NA) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.4) +
  geom_text(data = p_lab, aes(x = 4.6, y = 0.62, label = lab),
            inherit.aes = FALSE, size = 2.2, family = "Arial",
            fontface = "bold", colour = COL_INK) +
  facet_wrap(~db, nrow = 1) +
  scale_colour_manual(values = c("Positive shock" = COL_POS, "Negative shock" = COL_NEG)) +
  scale_fill_manual(values   = c("Positive shock" = COL_POS, "Negative shock" = COL_NEG)) +
  scale_x_continuous(breaks = 0:6) +
  labs(x = "Horizon h (months)", y = expression(beta[h]~"(change spec)"), tag = "b") +
  theme_nature() +
  theme(legend.position = "top",
        panel.spacing = unit(4, "mm"))

# ---------- Panel c 数据 ----------
dc <- read_csv(F_C, show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  filter(db == "GDELT", spec == "change", ally_set == "M3_six") %>%
  transmute(h,
            ally    = beta_neg_ally_total,  ally_lo    = beta_neg_ally_total - 1.96 * se_neg_ally_total,
            ally_hi = beta_neg_ally_total + 1.96 * se_neg_ally_total,
            non     = beta_neg_nonally,     non_lo     = beta_neg_nonally - 1.96 * se_neg_nonally,
            non_hi  = beta_neg_nonally + 1.96 * se_neg_nonally,
            interact = beta_interact, p_interact)
dcl <- bind_rows(
  dc %>% transmute(h, grp = "US allies (n=6)", beta = ally, lo = ally_lo, hi = ally_hi),
  dc %>% transmute(h, grp = "Non-allies",       beta = non,  lo = non_lo,  hi = non_hi)) %>%
  mutate(grp = factor(grp, levels = c("US allies (n=6)", "Non-allies")))
# QA 闸门
qc <- dc %>% filter(h == 1)
stopifnot(abs(qc$interact - (-0.451)) < 0.01, abs(qc$p_interact - 0.005) < 0.002)

pc <- ggplot(dcl, aes(h, beta, colour = grp, fill = grp)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4, colour = COL_REF) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.18, colour = NA) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.4) +
  annotate("segment", x = 1, xend = 1, y = qc$non, yend = qc$ally,
           arrow = arrow(ends = "both", length = unit(1.6, "mm")),
           linewidth = 0.45, colour = COL_INK) +
  annotate("text", x = 1.30, y = -0.30, hjust = 0,
           label = sprintf("interaction = %.2f (p = %.3f)", qc$interact, qc$p_interact),
           size = 2.2, family = "Arial", fontface = "bold", colour = COL_INK) +
  scale_colour_manual(values = c("US allies (n=6)" = COL_INK, "Non-allies" = COL_NS)) +
  scale_fill_manual(values   = c("US allies (n=6)" = COL_INK, "Non-allies" = COL_NS)) +
  scale_x_continuous(breaks = 0:6) +
  labs(x = "Horizon h (months)", y = expression(beta[h]~"(negative shock, GDELT)"), tag = "c") +
  theme_nature() +
  theme(legend.position = c(0.74, 0.13))

# ---------- 合成：a 上（hero），b 左下 / c 右下 ----------
p <- pa / (pb | pc) + plot_layout(heights = c(1, 1.15), widths = c(1.15, 1))
save_pub(p, OUT, 180, 140)
cat("fig04 done; QA passed",
    "(a: GDELT 0.399/0.369/0.168, ICEWS 0.502/0.459/0.233;",
    "b: h0 GDELT -0.428/+0.260 p=0.20, ICEWS -0.812/+0.309 p=0.025;",
    "c: h1 interaction -0.451 p=0.005)\n")
