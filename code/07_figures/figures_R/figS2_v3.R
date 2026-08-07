# fig02_v2.R — Figure 2: Signed versus Absolute 效度棱镜

source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R")
ROOT <- "C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件"
qa_line <- function(...) cat("[QA]", paste(..., collapse = " "), "
")
suppressMessages(library(data.table))
suppressMessages(library(patchwork))

OUT <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/figS_附录图/output"
dir.create(OUT, showWarning = FALSE, recursive = TRUE)

cat("[fig02-v2] start\n")

# ---------- 0. 数据路径 ----------
CSV_FILE <- file.path(ROOT, "重跑_公平覆盖期_202607/01_PPML套件/fair/03_干净面板PPML/检验结果CSV/ppml_final.csv")
if (!file.exists(CSV_FILE)) stop("[ERR] ppml_final.csv 不存在")

dt <- fread(CSV_FILE, encoding = "UTF-8")

# ---------- 1. 解析 label ----------
dt[, db_prefix := sub("_.*$", "", label)]
dt[, db := factor(db_prefix,
                  levels = c("GD", "IW", "PH", "TS"),
                  labels = c("GDELT", "ICEWS", "Phoenix", "Tsinghua"))]
dt[, variant := sub("^[A-Z]+_", "", label)]
dt[, trade := sub(".*-", "", label)]
dt[, variant := mapply(function(v, t) sub(paste0("-", t, "$"), "", v), variant, trade)]
dt[variant == "", variant := "-"]
dt[, trade_label := factor(trade,
                           levels = c("Total", "Exports", "Imports"),
                           labels = c("Total trade", "Exports", "Imports"))]

# 只保留 aggregate 变体：signed ("-") 与 absolute ("abs")
dt_plot <- dt[variant %in% c("-", "abs")]
dt_plot[, variant_label := factor(variant,
                                  levels = c("-", "abs"),
                                  labels = c("Signed score", "Absolute score"))]
dt_plot[, ci_lo := cum - 1.96 * cum_se]
dt_plot[, ci_hi := cum + 1.96 * cum_se]
dt_plot[, sig := h0p < 0.05]

# ---------- 2. QA ----------
for (i in seq_len(nrow(dt_plot)))
  qa_line("CleanPanel-fair", dt_plot$db[i], dt_plot$variant_label[i], dt_plot$trade_label[i],
          sprintf("cum=%.4f se=%.4f h0p=%.3f", dt_plot$cum[i], dt_plot$cum_se[i], dt_plot$h0p[i]))
stopifnot(abs(dt_plot[db == "GDELT" & variant == "-" & trade == "Total"]$cum - 0.0617) < 0.0001)
cat("[QA] Clean panel 关键值闸门通过\n")

# ---------- 3. Panel a：连接点图 ----------
# 每个 db×trade 一行，signed 和 absolute 两个点用线连接
pa_dt <- dcast(dt_plot, db + trade_label ~ variant_label, value.var = c("cum", "cum_se", "h0p", "sig"))
pa_dt[, diverge := sign(`cum_Signed score`) != sign(`cum_Absolute score`)]
pa_dt[, db := factor(db, levels = c("GDELT", "ICEWS", "Phoenix", "Tsinghua"))]

# 构造 y 标签：db | trade，按数据库和贸易流排序
trade_levels <- c("Total trade", "Exports", "Imports")
db_levels    <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
y_levels_a <- rev(apply(expand.grid(db_levels, trade_levels), 1, paste, collapse = " | "))
pa_dt[, y_label := factor(paste(db, trade_label, sep = " | "), levels = y_levels_a)]

# 长格式用于 geom_point / geom_line
pa_long <- melt(dt_plot, id.vars = c("db", "trade_label", "variant_label", "sig"),
                measure.vars = c("cum"), variable.name = "metric", value.name = "value")
pa_long[, y_label := factor(paste(db, trade_label, sep = " | "), levels = y_levels_a)]
pa_dt[, diverge := factor(ifelse(diverge, "Divergent", "Concordant"),
                          levels = c("Concordant", "Divergent"))]
pa_long <- merge(pa_long, pa_dt[, .(db, trade_label, diverge)], by = c("db", "trade_label"))

# 当 signed 与 absolute 系数接近时，做小的垂直偏移避免重叠
pa_long[, y_num := as.numeric(y_label)]
pa_long[, y_off := y_num + ifelse(variant_label == "Signed score", 0.10, -0.10)]

pa <- ggplot(pa_long, aes(x = value, y = y_off)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.25, color = COL_REF) +
  geom_line(aes(group = y_label, color = diverge), linewidth = 0.8) +
  geom_point(aes(shape = variant_label, fill = db), color = COL_INK, size = 2.4, stroke = 0.5) +
  scale_color_manual(values = c("Concordant" = "#BBBBBB", "Divergent" = "#B2182B"),
                     name = NULL) +
  scale_fill_manual(values = DB_COLORS, name = NULL) +
  scale_shape_manual(values = c("Signed score" = 21, "Absolute score" = 22), name = NULL) +
  scale_y_continuous(breaks = seq_along(levels(pa_long$y_label)),
                     labels = levels(pa_long$y_label),
                     name = NULL, expand = expansion(add = 0.45)) +
  scale_x_continuous(name = "Cumulative coefficient") +
  labs(y = NULL, tag = "a") +
  guides(fill = guide_legend(nrow = 1, order = 1,
                              override.aes = list(color = DB_COLORS, stroke = 0.4)),
         shape = guide_legend(nrow = 1, order = 2),
         color = guide_legend(nrow = 1, order = 3)) +
  theme(legend.position = "top",
        legend.box = "vertical",
        legend.key.size = unit(3, "mm"),
        legend.spacing.y = unit(1, "mm"),
        legend.text = element_text(size = SZ_TICK),
        axis.text.y = element_text(size = SZ_TICK, color = COL_INK),
        axis.text.x = element_text(size = SZ_TICK),
        axis.title = element_text(size = SZ_AXIST),
        panel.grid = element_blank(),
        plot.tag = element_text(size = SZ_TAG, face = "bold", color = COL_INK))

# ---------- 4. Panel b：显著性/方向矩阵 ----------
mat_dt <- dt_plot[, .(db, variant_label, trade_label, cum, sig)]
mat_dt[, sign_col := ifelse(cum > 0, "Positive", ifelse(cum < 0, "Negative", "Zero"))]
y_levels_b <- rev(apply(expand.grid(db_levels, c("Signed score", "Absolute score")), 1, paste, collapse = " | "))
mat_dt[, y_label := factor(paste(db, variant_label, sep = " | "), levels = y_levels_b)]

# 颜色：正负方向 + 透明度表示显著性
sign_colors <- c("Positive" = "#2166AC", "Negative" = "#B2182B", "Zero" = "#CCCCCC")

pb <- ggplot(mat_dt, aes(x = trade_label, y = y_label, fill = sign_col, alpha = ifelse(sig, 1, 0.4))) +
  geom_tile(color = COL_AXIS, linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.3f", cum),
                color = ifelse(sig, "white", COL_INK),
                fontface = ifelse(sig, "bold", "plain")),
            size = 2.4, vjust = 0.4) +
  scale_fill_manual(values = sign_colors, name = NULL) +
  scale_color_identity() +
  scale_alpha_identity() +
  scale_y_discrete(name = NULL, expand = expansion(add = 0.4)) +
  labs(x = "Trade flow", y = NULL, tag = "b") +
  theme(legend.position = "top",
        legend.key.size = unit(3, "mm"),
        legend.text = element_text(size = SZ_TICK),
        axis.text.x = element_text(size = SZ_TICK),
        axis.text.y = element_text(size = SZ_TICK, color = COL_INK),
        axis.title = element_text(size = SZ_AXIST),
        panel.grid = element_blank(),
        plot.tag = element_text(size = SZ_TAG, face = "bold", color = COL_INK))

# ---------- 5. 拼版与导出 ----------
fig <- pa + pb + plot_layout(widths = c(1.3, 1.0))

save_pub(fig, file.path(OUT, "figS2"), 170, 135)
cat("done fig02_v2\n")
