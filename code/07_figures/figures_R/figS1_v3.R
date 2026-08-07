# figS1_v3.R — 附录图 S1：GDELT 方向分解哑铃图（CHN→Partner vs Partner→CHN，h=0/6）

suppressMessages({source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R"); library(data.table)})
ROOT <- "C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件"
DIR_FILE <- file.path(ROOT, "重跑_公平覆盖期_202607/01_PPML套件/fair/02_方向分解/检验结果CSV/directional_decomp.csv")
OUT <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/figS_附录图/output/figS1"
stopifnot(file.exists(DIR_FILE))

dir_dt <- fread(DIR_FILE, encoding = "UTF-8")
dir_dt[, trade_label := factor(trade, levels = c("Total", "Exports", "Imports"),
                               labels = c("Total trade", "Exports", "Imports"))]
dir_dt[, `:=`(sig = pv < 0.05, ci_lo = Est - 1.96 * SE, ci_hi = Est + 1.96 * SE)]
plot_b <- dir_dt[h %in% c(0, 6)]
cat("[QA] rows:", nrow(plot_b), "\n")

DIR_COLORS <- c("CHN -> Partner" = "#2166AC", "Partner -> CHN" = "#B2182B")
plot_b[, y_base := as.numeric(factor(h, levels = c(0, 6)))]
plot_b[, y_pos := y_base + ifelse(direction == "CHN -> Partner", 0.13, -0.13)]

p <- ggplot(plot_b, aes(x = Est, y = y_pos, color = direction, group = direction)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.45, color = COL_REF) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), orientation = "y", width = 0.12, linewidth = 0.6) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2.4, stroke = 0.6, shape = 21, fill = "white") +
  facet_grid(. ~ trade_label) +
  scale_color_manual(values = DIR_COLORS, name = NULL) +
  scale_y_continuous(breaks = c(1, 2), labels = c("h = 0", "h = 6"),
                     name = NULL, expand = expansion(add = 0.4)) +
  scale_x_continuous(name = "Coefficient") +
  labs(tag = NULL) +
  theme_nature() +
  theme(legend.position = "top", panel.spacing = unit(3, "mm"))

save_pub(p, OUT, 180, 80)
cat("done figS1\n")
