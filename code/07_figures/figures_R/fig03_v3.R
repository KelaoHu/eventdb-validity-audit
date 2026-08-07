# fig03_v3.R — 图 3「案例一：只有 GDELT 进入贸易决策」

suppressMessages({source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R")})
library(data.table)

ROOT <- "C:/Users/胡克劳/Desktop/311工程数据"
IRF_DIR <- file.path(ROOT, "03_检验与分析套件/重跑_公平覆盖期_202607/01_PPML套件/--file=fair/01_基准传导_季度冲击/检验结果CSV")
SANC_FILE <- file.path(ROOT, "03_检验与分析套件/19_制裁事件进口方向可观察性检验/02_输出表格/event_import_changes.csv")
OUT <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/fig03_案例一/output/fig03"

# ---------- Panel a 数据 ----------
dbs <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
spec_map <- c(GDELT = "GD-Total", ICEWS = "IW-Total", Phoenix = "PH-Total", Tsinghua = "TS-Total")
irf <- rbindlist(lapply(names(spec_map), function(d) {
  dt <- fread(file.path(IRF_DIR, d, "irf_all.csv"), encoding = "UTF-8")
  dt[spec == spec_map[[d]] & trade %in% c("Trade_Total", "Trade_Exports", "Trade_Imports"),
     .(db = d, trade, h, Est, pv)]
}))
cat("rows per db:\n"); print(irf[, .N, by = db])
stopifnot(length(unique(irf$db)) == 4)
irf[, `:=`(trade = factor(trade, levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                          labels = c("Total trade", "Exports", "Imports")),
           db = factor(db, levels = rev(dbs)),
           sig = pv < 0.05)]
gd <- irf[db == "GDELT" & trade == "Total trade" & h == 0]
stopifnot(abs(gd$Est - 0.0127) < 0.0005, abs(gd$pv - 0.026) < 0.005)

pa <- ggplot(irf, aes(h, db)) +
  geom_tile(aes(fill = Est), colour = "white", linewidth = 0.4) +
  geom_text(data = irf[sig == TRUE], aes(label = "*"), size = 4, colour = COL_INK,
            family = "Arial", vjust = 0.65) +
  facet_grid(. ~ trade) +
  scale_fill_gradient2(low = DIV_NEG, mid = DIV_MID, high = DIV_POS, midpoint = 0,
                       limits = c(-0.022, 0.022), oob = scales::squish,
                       name = "Coefficient") +
  scale_x_continuous(breaks = 0:6) +
  labs(x = "Months after shock (h)", y = NULL, tag = "a") +
  theme_nature() +
  theme(legend.position = "bottom",
        legend.key.width = unit(8, "mm"), legend.key.height = unit(2.6, "mm"),
        legend.title = element_text(size = SZ_TICK),
        axis.text.y = element_text(face = "bold"),
        panel.spacing = unit(2.5, "mm"))

# ---------- Panel b 数据（S6-1 提升） ----------
sanc <- fread(SANC_FILE, encoding = "UTF-8")
sanc_long <- rbind(
  sanc[, .(Country, t = "t = +1", pct = pct_change_1, dir = direction_1)],
  sanc[, .(Country, t = "t = +2", pct = pct_change_2, dir = direction_2)])
med <- sanc_long[, .(m = median(pct)), by = t]
n_up <- sanc_long[t == "t = +2", sum(dir == "Increase")]
stopifnot(nrow(sanc) == 22, n_up == 16)   # QA：22 事件，t=+2 上升 16/22（72.7%）

country_order <- sanc[, .(m = median(pct_change_2)), by = Country][order(m)]$Country
sanc_long[, Country := factor(Country, levels = country_order)]

oob_dt <- sanc_long[pct > 0.55]

pb <- ggplot(sanc_long, aes(pct, Country)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.45, colour = COL_REF) +
  geom_vline(data = med, aes(xintercept = m), linewidth = 0.8, colour = COL_INK,
             alpha = 0.55, show.legend = FALSE) +
  geom_point(aes(colour = dir), size = 1.8, alpha = 0.9) +
  geom_text(data = oob_dt, aes(x = 0.53, label = sprintf("(+%.0f%%)", pct * 100), colour = dir),
            hjust = 1, size = 1.8, family = "Arial", show.legend = FALSE) +
  geom_text(data = med, aes(x = 0.53, y = -Inf, label = sprintf("Median %+.1f%%", m * 100)),
            vjust = -0.9, hjust = 1, size = 2, family = "Arial", colour = COL_INK,
            alpha = 0.75, inherit.aes = FALSE) +
  facet_grid(t ~ .) +
  scale_colour_manual(values = c(Decrease = COL_NEG, Increase = COL_POS)) +
  scale_x_continuous(limits = c(-0.45, 0.55), oob = scales::squish,
                     labels = scales::percent_format(accuracy = 1)) +
  labs(x = "Import change relative to t = −1", y = NULL, tag = "b") +
  theme_nature() +
  theme(legend.position = "top",
        axis.text.y = element_text(size = 6),
        strip.text = element_text(hjust = 0),
        panel.spacing = unit(1.5, "mm"))

# ---------- 合成 ----------
p <- pa / pb + plot_layout(heights = c(1, 1.6))
save_pub(p, OUT, 180, 165)
cat("fig03 done; QA passed (GDELT h=0 0.0127/p=0.026; sanctions 22 events, 16/22 up at t=+2)\n")
