# fig06_v3.R — 图 6 案例二「效度是受众特定的」（三面板）

suppressMessages({
  source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R")
})

ROOT <- "C:/Users/胡克劳/Desktop/311工程数据"
F_S87 <- "data/appendix_tables/Table_S6_7_convergence.csv"   # repo-relative（从仓根目录运行）
F_S88 <- "data/appendix_tables/Table_S6_8_events.csv"
F_S85 <- "data/appendix_tables/Table_S6_5_case_enumeration.csv"
F_DIR <- file.path(ROOT, "03_检验与分析套件/重跑_公平覆盖期_202607/02_事件研究套件/fair/05_领导人会晤效应与双边关系/code/results/direction_summary.csv")
OUT <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/fig06_案例二/output/fig06"

read_sec <- function(path, header_line, n_rows) {
  ln <- readLines(path, encoding = "UTF-8")
  read.csv(textConnection(paste(ln[header_line + 0:n_rows], collapse = "\n")),
           stringsAsFactors = FALSE, check.names = FALSE)
}

# ---------- Panel a 数据 ----------
s87a <- read_sec(F_S87, 2, 4)   # between rho + CI
s87b <- read_sec(F_S87, 9, 4)   # FE beta/SE/p
pa_dt <- tibble(
  db     = factor(s87a$Database, levels = c("GDELT", "ICEWS", "Phoenix", "Tsinghua")),
  y      = 4:1,
  rho    = s87a$between_rho,
  lo     = s87a$CI_95_low,
  hi     = s87a$CI_95_high,
  beta   = s87b$beta,
  p_lab  = c("**", "**", "***", "*"))

# QA 闸门 a
stopifnot(abs(pa_dt$rho[pa_dt$db == "GDELT"] - 0.132) < 1e-3,
          abs(pa_dt$lo[pa_dt$db == "GDELT"] - (-0.413)) < 1e-3,
          abs(pa_dt$hi[pa_dt$db == "GDELT"] - 0.589) < 1e-3,
          abs(pa_dt$beta[pa_dt$db == "GDELT"] - 0.240) < 1e-3,
          abs(as.numeric(s87b$p[1]) - 0.002) < 1e-3,
          all(pa_dt$lo < 0 & pa_dt$hi > 0))   # 全部 CI 跨零

# ---------- Panel a 图 ----------
pa <- ggplot(pa_dt) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.45, colour = COL_REF) +
  geom_segment(aes(x = rho, xend = beta, y = y, yend = y),
               linewidth = 0.5, colour = "#BBBBBB") +
  geom_errorbar(aes(xmin = lo, xmax = hi, y = y), orientation = "y",
                width = 0.16, linewidth = LW_CI, colour = "#777777") +
  geom_point(aes(x = rho, y = y), size = PT_MAIN, colour = "#777777") +
  geom_point(aes(x = beta, y = y, colour = db), size = PT_MAIN) +
  geom_text(aes(x = rho, y = y - 0.28,
                label = gsub("^-0\\.00$", "0.00", sprintf("%+.2f", rho))),
            size = 2.2, family = "Arial", colour = "#555555") +
  geom_text(aes(x = beta, y = y + 0.26, label = paste0(sprintf("%.2f", beta), p_lab),
                colour = db), size = 2.2, family = "Arial", fontface = "bold") +
  # 手动图例
  annotate("point", x = -0.72, y = 4.72, size = PT_MAIN, colour = "#777777") +
  annotate("text", x = -0.66, y = 4.72, hjust = 0, size = 2.3, family = "Arial",
           colour = COL_INK, label = "Between-country Spearman \u03c1 (95% CI, all cross 0)") +
  annotate("point", x = 0.28, y = 4.72, size = PT_MAIN, colour = COL_INK) +
  annotate("text", x = 0.34, y = 4.72, hjust = 0, size = 2.3, family = "Arial",
           colour = COL_INK, label = "Within-country FE \u03b2 (all p < 0.05)") +
  annotate("text", x = -0.72, y = 0.68, hjust = 0, size = 1.9, family = "Arial",
           colour = "#666666", lineheight = 0.95,
           label = "\u03c1 and FE \u03b2 differ in units; shared axis illustrative") +
  scale_colour_manual(values = DB_COLORS, guide = "none") +
  scale_y_continuous(breaks = 4:1, labels = DB_LABELS[levels(pa_dt$db)],
                     limits = c(0.45, 4.95), expand = c(0, 0)) +
  scale_x_continuous(limits = c(-0.78, 1.32), breaks = seq(-0.5, 1.0, 0.5),
                     expand = c(0, 0)) +
  labs(x = "Convergence with Pew polling (\u03c1 between / FE \u03b2 within)",
       y = NULL, tag = "a") +
  theme_nature() +
  theme(axis.text.y = element_text(colour = DB_COLORS[levels(pa_dt$db)], face = "bold"))

# ---------- Panel b 数据 ----------
dir_gdelt <- read_csv(F_DIR, show_col_types = FALSE) %>%
  filter(db == "GDELT")
stopifnot(nrow(dir_gdelt) == 4)
get_mean <- function(cat) dir_gdelt$mean[dir_gdelt$category_4 == cat]
left_b <- tibble(
  lab = c("Chinese outbound visit", "Partner inbound visit",
          "Third-party meeting", "Remote talk"),
  y   = 4:1,
  val = c(get_mean("Chinese outbound visit"), get_mean("Partner inbound visit"),
          get_mean("Third-party meeting"), get_mean("Remote talk")),
  sig = c(TRUE, TRUE, TRUE, FALSE))           # Remote talk CI 跨零 (n.s.)
s88b <- read_sec(F_S88, 6, 3)
right_b <- tibble(
  lab = c("State-head visit", "Gov-head visit", "Third-party contact"),
  y   = c(3.7, 2.7, 1.7),                   # 按礼宾级别（信号成本）自上而下
  val = s88b$beta[match(c("state_head", "gov_head", "third_party"), s88b$Visit_level)],
  sig = c(TRUE, TRUE, FALSE))                 # third_party p=0.120 (n.s.)

# QA 闸门 b
stopifnot(abs(left_b$val[1] - 0.399) < 0.01, abs(left_b$val[2] - 0.369) < 0.01,
          abs(left_b$val[3] - 0.168) < 0.01,
          abs(right_b$val[2] - 0.277) < 0.01, abs(right_b$val[1] - 0.157) < 0.01)

# ---------- Panel b 图（左右分面，各立零线；负值不再越界） ----------
left_b <- left_b %>% mutate(lab = factor(lab, levels = rev(lab)))
right_b <- right_b %>% mutate(lab = factor(lab, levels = rev(lab)))

pbl <- ggplot(left_b, aes(x = val, y = lab)) +
  geom_col(aes(fill = ifelse(sig, "sig", "ns")), width = 0.55, orientation = "y") +
  geom_vline(xintercept = 0, linewidth = 0.5, colour = COL_AXIS) +
  geom_text(aes(x = val + 0.015,
                label = paste0(sprintf("%.2f", val), ifelse(sig, "", " n.s.")),
                colour = ifelse(sig, "sig", "ns")),
            hjust = 0, size = 2.2, family = "Arial", fontface = "bold", show.legend = FALSE) +
  annotate("text", x = 0.50, y = 0.52, hjust = 1, size = 2.0, family = "Arial",
           colour = "#555555",
           label = "Signal cost falls top → bottom; effect tracks the gradient") +
  scale_fill_manual(values = c(sig = unname(DB_COLORS["GDELT"]), ns = COL_NS), guide = "none") +
  scale_colour_manual(values = c(sig = unname(DB_COLORS["GDELT"]), ns = COL_NS), guide = "none") +
  scale_x_continuous(limits = c(0, 0.52), expand = c(0, 0)) +
  labs(title = "Score dimension (elite audiences, GDELT)",
       x = "Mean score shift", y = NULL, tag = "b") +
  theme_nature() +
  theme(plot.title = element_text(size = 7.0, face = "bold",
                                  colour = unname(DB_COLORS["GDELT"])),
        axis.text.y = element_text(size = 6.5))

pbr <- ggplot(right_b, aes(x = val, y = lab)) +
  geom_col(aes(fill = ifelse(sig, "sig", "ns")), width = 0.55, orientation = "y") +
  geom_vline(xintercept = 0, linewidth = 0.5, colour = COL_AXIS) +
  geom_text(aes(x = ifelse(val >= 0, val + 0.015, val - 0.015),
                label = paste0(sprintf("%+.2f", val), ifelse(sig, "", " n.s.")),
                hjust = ifelse(val >= 0, 0, 1),
                colour = ifelse(sig, "sig", "ns")),
            size = 2.2, family = "Arial", fontface = "bold", show.legend = FALSE) +
  annotate("text", x = 0.40, y = 0.80, hjust = 1, size = 2.0, family = "Arial",
           colour = "#555555", lineheight = 0.95,
           label = "Gradient reverses:
gov-head > state-head") +
  scale_fill_manual(values = c(sig = COL_NEG, ns = COL_NS), guide = "none") +
  scale_colour_manual(values = c(sig = COL_NEG, ns = COL_NS), guide = "none") +
  scale_x_continuous(limits = c(-0.38, 0.42), expand = c(0, 0)) +
  labs(title = "Public-opinion dimension (Pew)",
       x = "FE β on polling z", y = NULL) +
  theme_nature() +
  theme(plot.title = element_text(size = 7.0, face = "bold", colour = COL_NEG),
        axis.text.y = element_text(size = 6.5))

pb <- (pbl | pbr) + plot_layout(widths = c(1.12, 1)) +
  plot_annotation(caption = "Constructs differ — left: direction of leader contact; right: rank of visiting leader. Juxtaposition illustrative, not a like-for-like test.") &
  theme(plot.caption = element_text(size = 5.5, colour = "#666666", hjust = 0, family = "Arial"))

# ---------- Panel c 数据 ----------
s85 <- read_csv(F_S85, show_col_types = FALSE, locale = locale(encoding = "UTF-8"))
cases <- s85 %>%
  filter((country == "France" & year == 2008) |
         (country == "South Korea" & year == 2017) |
         (country == "Australia" & year == 2018)) %>%
  distinct(country, year, .keep_all = TRUE) %>%     # 法国 2008 两条合并
  arrange(country)
stopifnot(nrow(cases) == 3)

# QA 闸门 c
qa <- function(cty, a, b) {
  r <- cases[cases$country == cty, ]
  stopifnot(abs(r$pz_prev - a) < 0.02, abs(r$pz_this - b) < 0.02)
}
qa("France", 1.695, -1.027); qa("South Korea", 0.964, -0.672); qa("Australia", 1.377, 0.392)

seg_dt <- cases %>% transmute(country, x0 = prev_year, y0 = pz_prev, x1 = year, y1 = pz_this)
lab_dt <- tibble(
  country = c("France", "South Korea", "Australia"),
  x = c(2006.5, 2013.8, 2017.9),
  y = c(1.30, 0.62, 1.60),
  hj = c(0, 1, 0.5),
  lab = c("France 2008 \u2014 torch relay; Dalai Lama meeting",
          "South Korea 2017\nTHAAD retaliation (Lotte)",
          "Australia 2018\nHuawei 5G ban"))

pc <- ggplot(seg_dt) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4, colour = COL_REF) +
  geom_segment(aes(x = x0, y = y0, xend = x1, yend = y1),
               linewidth = 0.8, colour = "#555555",
               arrow = arrow(length = unit(1.6, "mm"), type = "closed")) +
  geom_point(aes(x = x0, y = y0), size = PT_MAIN, shape = 21,
             fill = "white", colour = "#555555", stroke = 0.8) +
  geom_point(aes(x = x1, y = y1), size = PT_MAIN, colour = COL_NEG) +
  geom_text(aes(x = x0, y = y0, label = sprintf("%+.2f", y0)),
            hjust = 1.15, size = 2.2, family = "Arial", colour = "#555555") +
  geom_text(aes(x = x1, y = y1, label = sprintf("%+.2f", y1)),
            hjust = -0.15, size = 2.2, family = "Arial", fontface = "bold",
            colour = COL_NEG) +
  geom_text(data = lab_dt, aes(x = x, y = y, label = lab, hjust = hj),
            size = 2.2, family = "Arial", colour = COL_INK) +
  annotate("text", x = 2004.8, y = 2.05, hjust = 0, size = 2.3, family = "Arial",
           colour = "#555555",
           label = "15/19 cases with before-and-after polling data show declines (79%)") +
  scale_x_continuous(breaks = seq(2006, 2018, 2), limits = c(2004.6, 2019.4),
                     expand = c(0, 0)) +
  scale_y_continuous(limits = c(-1.45, 2.2), breaks = seq(-1, 2, 1), expand = c(0, 0)) +
  labs(x = NULL, y = "Polling z-score", tag = "c") +
  theme_nature()

# ---------- 合成 ----------
p <- pa / pb / pc + plot_layout(heights = c(0.9, 1.55, 1.0))
save_pub(p, OUT, 180, 140)
cat("fig06 done; QA passed:",
    "a(GDELT \u03c1=+0.132[-0.413,+0.589], FE \u03b2=0.240 p=0.002, all between CIs cross 0),",
    "b(0.399/0.369/0.168 vs 0.277/0.157),",
    "c(France +1.695\u2192-1.027, Korea +0.964\u2192-0.672, Australia +1.377\u2192+0.392)\n")
