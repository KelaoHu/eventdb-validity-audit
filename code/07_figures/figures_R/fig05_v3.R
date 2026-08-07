# fig04_v2.R — Figure 4: 因果识别稳健性三联画

source("C:/Users/胡克劳/Desktop/311工程论文_图件_R/00_theme_v4.R")
ROOT <- "C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件"
qa_line <- function(...) cat("[QA]", paste(..., collapse = " "), "\n")
suppressMessages(library(data.table))
suppressMessages(library(patchwork))

OUT <- "C:/Users/胡克劳/Desktop/311工程论文_图件_R/fig05_稳健性/output"
dir.create(OUT, showWarning = FALSE, recursive = TRUE)

cat("[fig04-v2] start\n")

# ---------- 0. 数据路径 ----------
FSCAN_FILE <- file.path(ROOT, "重跑_公平覆盖期_202607/01_PPML套件/fair/05_频率响应扫描/检验结果CSV/B_freqscan.csv")
FWD_FILE   <- file.path(ROOT, "重跑_公平覆盖期_202607/01_PPML套件/fair/06_前向效应/检验结果CSV/D_forward.csv")
AR1_FILE   <- file.path(ROOT, "重跑_公平覆盖期_202607/01_PPML套件/fair/04_AR1残差回归/检验结果CSV/A_AR1.csv")
if (!file.exists(FSCAN_FILE)) stop("[ERR] B_freqscan.csv 不存在")
if (!file.exists(FWD_FILE))   stop("[ERR] D_forward.csv 不存在")
if (!file.exists(AR1_FILE))   stop("[ERR] A_AR1.csv 不存在")

DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")

# ---------- 1. Panel a：频率响应扫描 ----------
fdt <- fread(FSCAN_FILE, encoding = "UTF-8")
fdt[, db := factor(db, levels = DBS)]
fdt[, sig := h0p < 0.05]

# QA
for (i in seq_len(nrow(fdt)))
  qa_line("Freqscan-fair", fdt$db[i], paste0("k=", fdt$k[i]),
          sprintf("cum=%.4f p=%.3f", fdt$cum[i], fdt$h0p[i]))
stopifnot(abs(fdt[db == "GDELT" & k == 1]$cum - 0.0127) < 0.0001)
stopifnot(abs(fdt[db == "GDELT" & k == 24]$cum - 0.0054) < 0.0001)
cat("[QA] Frequency scan 关键值闸门通过\n")

pa <- ggplot(fdt, aes(x = k, y = cum, color = db, group = db)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.25, color = COL_REF) +
  annotate("rect", xmin = 0.8, xmax = 6.2, ymin = -Inf, ymax = Inf,
           fill = "#E3E3E3", alpha = 0.55, color = NA) +
  geom_line(linewidth = 0.8, position = position_dodge(width = 0.3)) +
  geom_point(aes(shape = sig), size = 2.4, stroke = 0.5,
             position = position_dodge(width = 0.3)) +
  annotate("text", x = 3.5, y = max(fdt$cum) * 1.16, label = "Short-term window",
           size = 2.3, color = COL_INK, fontface = "italic") +
  scale_color_manual(values = DB_COLORS, name = NULL) +
  scale_shape_manual(values = c("TRUE" = 16, "FALSE" = 21), name = NULL,
                     labels = c("TRUE" = "p < 0.05", "FALSE" = "n.s."),
                     guide = guide_legend(override.aes = list(colour = "grey40", size = 1.8))) +
  scale_x_continuous(breaks = unique(fdt$k), name = "Window length k (months)") +
  scale_y_continuous(name = "Cumulative coefficient",
                     expand = expansion(mult = c(0.08, 0.26))) +
  labs(tag = "a") +
  theme(legend.position = "top",
        legend.key.size = unit(3, "mm"),
        legend.text = element_text(size = SZ_TICK),
        axis.text.x = element_text(size = SZ_TICK),
        axis.text.y = element_text(size = SZ_TICK),
        axis.title = element_text(size = SZ_AXIST),
        panel.grid = element_blank(),
        plot.tag = element_text(size = SZ_TAG, face = "bold", color = COL_INK))

# ---------- 2. Panel b：前向效应 ----------
fwdt <- fread(FWD_FILE, encoding = "UTF-8")
fwdt[, sig := pv < 0.05]
fwdt[, ci_lo := Est - 1.96 * SE]
fwdt[, ci_hi := Est + 1.96 * SE]

# QA
for (i in seq_len(nrow(fwdt)))
  qa_line("Forward-fair", paste0("h=", fwdt$h[i]),
          sprintf("β=%.4f p=%.3f", fwdt$Est[i], fwdt$pv[i]))
stopifnot(abs(fwdt[h == -2]$Est - 0.0140) < 0.0001)
stopifnot(abs(fwdt[h == 0]$Est - 0.0127) < 0.0001)
cat("[QA] Forward effects 关键值闸门通过\n")

pb <- ggplot(fwdt, aes(x = h, y = Est)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.25, color = COL_REF) +
  geom_vline(xintercept = 0, linetype = "dotted", linewidth = 0.4, color = COL_REF) +
  annotate("rect", xmin = -3.5, xmax = -0.5, ymin = -Inf, ymax = Inf,
           fill = "#E3E3E3", alpha = 0.55, color = NA) +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), fill = DB_COLORS["GDELT"], alpha = 0.10) +
  geom_line(color = DB_COLORS["GDELT"], linewidth = 0.7) +
  geom_point(aes(fill = sig, color = sig), size = 2.4, stroke = 0.5, shape = 21) +
  annotate("text", x = -2, y = min(fwdt$ci_lo) * 0.85, label = "No anticipation",
           size = 2.3, color = COL_INK, fontface = "italic") +
  annotate("text", x = 3, y = max(fwdt$ci_hi) * 0.95, label = "Effect persists",
           size = 2.3, color = DB_COLORS["GDELT"], fontface = "italic") +
  geom_text(data = fwdt[sig == FALSE], aes(y = Est - 0.004), label = "n.s.",
            size = 2.0, color = "grey45", family = "Arial") +
  scale_fill_manual(values = c("TRUE" = as.character(DB_COLORS["GDELT"]),
                               "FALSE" = "white"),
                    guide = "none") +
  scale_color_manual(values = c("TRUE" = as.character(DB_COLORS["GDELT"]),
                                "FALSE" = as.character(DB_COLORS["GDELT"])),
                     guide = "none") +
  scale_x_continuous(breaks = fwdt$h, name = "Horizon h (months)") +
  scale_y_continuous(name = "Coefficient") +
  labs(tag = "b") +
  theme(axis.text.x = element_text(size = SZ_TICK),
        axis.text.y = element_text(size = SZ_TICK),
        axis.title = element_text(size = SZ_AXIST),
        panel.grid = element_blank(),
        plot.tag = element_text(size = SZ_TAG, face = "bold", color = COL_INK))

# ---------- 3. Panel c：AR1 残差累计效应 ----------
adt <- fread(AR1_FILE, encoding = "UTF-8")
adt[, db := factor(db, levels = DBS)]
adt[, trade_label := factor(sub(".*-", "", label),
                            levels = c("Total", "Export", "Import"),
                            labels = c("Total trade", "Exports", "Imports"))]
adt[, ci_lo := cum - 1.96 * cum_se]
adt[, ci_hi := cum + 1.96 * cum_se]
adt[, sig := h0p < 0.05]

# QA
for (i in seq_len(nrow(adt)))
  qa_line("AR1-fair", adt$db[i], adt$trade_label[i],
          sprintf("cum=%.4f se=%.4f h0=%.4f p=%.3f", adt$cum[i], adt$cum_se[i], adt$h0[i], adt$h0p[i]))
stopifnot(abs(adt[db == "GDELT" & grepl("AR-Total", label)]$cum - 0.0721) < 0.0001)
stopifnot(abs(adt[db == "GDELT" & grepl("AR-Total", label)]$h0 - 0.0103) < 0.0001)
cat("[QA] AR1 residual 关键值闸门通过\n")

# y 标签组合：db + trade
adt[, y_label := paste(db, trade_label, sep = " | ")]
adt[, y_label := factor(y_label, levels = rev(unique(y_label[order(as.numeric(db), as.numeric(trade_label))])))]

pc <- ggplot(adt, aes(y = y_label, x = cum)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.25, color = COL_REF) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi, y = y_label, color = db),
                orientation = "y", width = 0.2,
                linewidth = 0.6, show.legend = FALSE) +
  geom_point(aes(color = db, fill = db, shape = sig), size = 2.4, stroke = 0.5,
             show.legend = FALSE) +
  geom_text(aes(x = ci_hi + 0.006, label = sprintf("%.3f", cum), color = db),
            hjust = 0, size = 2.0, family = "Arial", show.legend = FALSE) +
  scale_color_manual(values = DB_COLORS) +
  scale_fill_manual(values = DB_COLORS) +
  scale_shape_manual(values = c("TRUE" = 16, "FALSE" = 21), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0.12, 0.35)),
                     name = "Cumulative coefficient (AR(1) residual)") +
  labs(y = NULL, tag = "c") +
  theme(axis.text.y = element_text(size = SZ_TICK, color = COL_INK),
        axis.text.x = element_text(size = SZ_TICK),
        axis.title = element_text(size = SZ_AXIST),
        panel.grid = element_blank(),
        plot.tag = element_text(size = SZ_TAG, face = "bold", color = COL_INK))

# ---------- 4. 拼版与导出 ----------
fig <- (pa + pb) / pc + plot_layout(heights = c(1.0, 1.2))

save_pub(fig, file.path(OUT, "fig05"), 180, 165)
cat("done fig04_v2\n")
