# fig01_v6_heatmap.R — 图 1「一个时代，25 段关系」
# 面板 a：25 国 GDELT–ICEWS Spearman ρ 蓝色热力图（替代世界地图，2026-08-08）
# 面板 b：712 条黄金标准事件年度分布（不变）
# QA 闸门：Japan 0.633 / Brazil 0.031（±0.005）；n=25；事件 712
suppressMessages({
  source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R")
})

ROOT <- "C:/Users/胡克劳/Desktop/311工程数据"
COR_FILE <- file.path(ROOT, "02_中间数据_分数与面板/聚合算法脚本/3.1算法分析套件/01_四库多种算法相关性分析_R/output/tables/country_level_correlations.csv")
EV_FILE  <- file.path(ROOT, "01_源数据/自建事件库/自建事件库_25国_17类_712条事件.csv")
OUT <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/fig01_时代与梯度/output/fig01"

# ---------- 数据 ----------
cor_dt <- read_csv(COR_FILE, show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  filter(Index_Type == "Aggregated", Algorithm == "Geometric Mean", pair == "GDELT_vs_ICEWS") %>%
  select(Partner, spearman) %>%
  arrange(desc(spearman))
stopifnot(nrow(cor_dt) == 25)
stopifnot(abs(cor_dt$spearman[cor_dt$Partner == "Japan"] - 0.633) < 0.005,
          abs(cor_dt$spearman[cor_dt$Partner == "Brazil"] - 0.031) < 0.005)

ev <- read_csv(EV_FILE, show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>%
  mutate(year = as.integer(substr(event_date, 1, 4))) %>%
  count(year)
stopifnot(sum(ev$n) == 712)

# ---------- Panel a：蓝色热力图（2 列 × 13 行瓷砖阵）----------
hm <- cor_dt %>%
  mutate(rank = row_number(),
         col = if_else(rank <= 13, 0, 1),
         row = if_else(rank <= 13, rank, rank - 13),
         x_tile = col * 2 + 1,            # 色块中心 x：1 或 3
         x_name = col * 2 + 0.42,         # 国名右对齐位置
         lab_col = if_else(spearman > 0.32, "white", COL_INK))

pa <- ggplot(hm, aes(y = -row)) +
  geom_tile(aes(x = x_tile, fill = spearman), colour = "white", linewidth = 0.8,
            width = 1.06, height = 0.96) +
  geom_text(aes(x = x_name, label = Partner), hjust = 1, size = 2.4,
            family = "Arial", colour = COL_INK) +
  geom_text(aes(x = x_tile, label = sprintf("%.2f", spearman), colour = lab_col),
            size = 2.6, family = "Arial", fontface = "bold", show.legend = FALSE) +
  scale_colour_identity() +
  scale_fill_gradient(low = SEQ_LOW, high = SEQ_HIGH,
                      name = "GDELT–ICEWS\nSpearman ρ", breaks = c(0, 0.2, 0.4, 0.6),
                      limits = c(0, 0.65)) +
  scale_x_continuous(limits = c(-0.55, 3.8), expand = c(0, 0)) +
  coord_cartesian(expand = FALSE) +
  labs(tag = "a") +
  theme_void(base_family = "Arial") +
  theme(legend.position = "right",
        legend.title = element_text(size = 7, colour = COL_INK, lineheight = 0.9),
        legend.text = element_text(size = 6.5, colour = COL_INK),
        legend.key.width = unit(3, "mm"), legend.key.height = unit(6, "mm"),
        plot.tag = element_text(size = SZ_TAG, face = "bold", colour = COL_INK),
        plot.tag.position = c(0.005, 0.995),
        plot.margin = margin(2, 4, 2, 4))

# ---------- Panel b：时代带（不变） ----------
anchors <- tibble(
  year = c(2002, 2008, 2013, 2018, 2020, 2025),
  lab  = c("2001-12 WTO\naccession", "Global\nfinancial crisis", "Belt & Road\nInitiative",
           "US–China\ntrade war", "COVID-19\npandemic", "Reciprocal\ntariffs"),
  hj  = c(0, 0.5, 0.5, 0.5, 0.5, 1))
maxn <- max(ev$n)

pb <- ggplot(ev, aes(year, n)) +
  geom_col(fill = COL_POS, width = 0.72, alpha = 0.88) +
  geom_segment(data = anchors, aes(x = year, xend = year, y = 0, yend = maxn * 1.02),
               linetype = "dashed", linewidth = 0.45, colour = COL_REF, inherit.aes = FALSE) +
  geom_text(data = anchors, aes(x = year, y = maxn * 1.13, label = lab, hjust = hj),
            size = 2.1, lineheight = 0.9, colour = COL_INK, family = "Arial") +
  scale_x_continuous(breaks = seq(2002, 2025, by = 4), limits = c(2001, 2026),
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.22))) +
  labs(x = NULL, y = "Gold-standard events (n)", tag = "b") +
  theme_nature()

# ---------- 合成 ----------
p <- pa / pb + plot_layout(heights = c(1.7, 1))
save_pub(p, OUT, 180, 150)
cat("fig01 done; QA passed (Japan 0.633, Brazil 0.031, n=25, events 712)\n")
