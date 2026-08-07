# 00_theme_v4.R — 新图件体系全局主题（v20 六主图，2026-07-31）

suppressMessages({library(ggplot2); library(patchwork); library(dplyr); library(tidyr); library(readr); library(ggrepel)})

# ---- 分类色：四库（跨图一致，色盲安全） ----
DB_COLORS <- c(GDELT = "#2166AC", ICEWS = "#E69F00", Phoenix = "#7570B3", Tsinghua = "#CC79A7")
DB_LABELS <- c(GDELT = "GDELT", ICEWS = "ICEWS", Phoenix = "Phoenix", Tsinghua = "Tsinghua (expert)")

# ---- 语义色：方向/符号（全六图统一） ----
COL_NEG <- "#B2182B"   # 负向/下降/冲突（深红）
COL_POS <- "#2166AC"   # 正向/上升/合作（深蓝）
COL_NEU <- "#999999"   # 不显著/中性
COL_NS  <- "#999999"
COL_REF <- "#666666"
COL_INK <- "#1A1A1A"
COL_AXIS<- "#333333"
COL_BAND<- "#F2F2F2"

# 顺序色带（地图/热图单极量）
SEQ_LOW <- "#F7FBFF"; SEQ_HIGH <- "#08306B"
# 发散色带（双极系数）
DIV_NEG <- "#B2182B"; DIV_MID <- "#F7F7F7"; DIV_POS <- "#2166AC"

darken <- function(hex, f = 0.55) { v <- col2rgb(hex)/255; rgb(v[1]*f, v[2]*f, v[3]*f) }

SZ_TAG   <- 9; SZ_PTITLE <- 8; SZ_AXIST <- 7.5; SZ_TICK <- 7; SZ_ANNO <- 7
LW_CI <- 0.9; PT_MAIN <- 2.6

theme_nature <- function(base_size = 7.5) {
  theme_classic(base_size = base_size, base_family = "Arial") +
    theme(
      axis.line  = element_line(linewidth = 0.4, colour = COL_AXIS),
      axis.ticks = element_line(linewidth = 0.4, colour = COL_AXIS),
      axis.title = element_text(size = SZ_AXIST, colour = COL_INK),
      axis.text  = element_text(size = SZ_TICK, colour = COL_INK),
      legend.position = "top", legend.direction = "horizontal",
      legend.title = element_blank(),
      legend.text = element_text(size = SZ_TICK, colour = COL_INK),
      legend.key.size = unit(3.4, "mm"), legend.key.spacing.x = unit(3.5, "mm"),
      legend.background = element_blank(),
      panel.grid = element_blank(),
      strip.background = element_blank(),
      strip.text = element_text(size = SZ_PTITLE, face = "bold", colour = COL_INK),
      plot.tag = element_text(size = SZ_TAG, face = "bold", colour = COL_INK),
      plot.tag.position = c(0.005, 0.995),
      plot.margin = margin(2, 4, 2, 4)
    )
}

theme_map <- function() {
  theme_void(base_family = "Arial") +
    theme(legend.position = "right",
          legend.title = element_text(size = SZ_AXIST, colour = COL_INK),
          legend.text = element_text(size = SZ_TICK, colour = COL_INK),
          plot.tag = element_text(size = SZ_TAG, face = "bold", colour = COL_INK),
          plot.margin = margin(2, 2, 2, 2))
}

save_pub <- function(p, stem, w_mm, h_mm) {
  dir.create(dirname(stem), showWarnings = FALSE, recursive = TRUE)
  ggsave(paste0(stem, ".pdf"), p, width = w_mm, height = h_mm, units = "mm", device = cairo_pdf)
  ggsave(paste0(stem, ".svg"), p, width = w_mm, height = h_mm, units = "mm")
  ggsave(paste0(stem, ".tiff"), p, width = w_mm, height = h_mm, units = "mm",
         device = "tiff", dpi = 300, compression = "lzw")
  ggsave(paste0(stem, "_preview.png"), p, width = w_mm, height = h_mm, units = "mm",
         device = ragg::agg_png, dpi = 150, bg = "white")
  ggsave(paste0(stem, "_300.png"), p, width = w_mm, height = h_mm, units = "mm",
         device = ragg::agg_png, dpi = 300, bg = "white")
  invisible(stem)
}
