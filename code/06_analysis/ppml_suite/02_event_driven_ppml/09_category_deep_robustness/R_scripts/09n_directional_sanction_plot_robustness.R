# 09n_directional_sanction_plot_robustness.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

CSV_PATH <- file.path(TEST_DIR, "检验结果CSV", "09m_directional_sanction_robustness.csv")
if (!file.exists(CSV_PATH)) stop("请先运行 09m_directional_sanction_robustness.R")

dt <- fread(CSV_PATH, encoding = "UTF-8")
setnames(dt, sub("^\ufeff", "", names(dt)))

# 变量标签
dt[, var_label := fcase(
  variable == "Cat_科技管制_对华", "科技管制（对华）",
  variable == "Cat_经贸制裁_对华", "经贸制裁（对华）",
  variable == "Cat_经贸制裁_对华_含模糊", "经贸制裁（对华，含模糊）",
  default = variable
)]

# 为绘图排序：将“加入 Event_Negative”放在最上方基准位置
test_order <- c(
  "加入 Event_Negative",
  "基准 PPML（仅17类）",
  "排除多边/对伙伴变量",
  "排除对伙伴事件期",
  "严格关键词（仅对华）",
  "包含模糊事件",
  "排除疫情期",
  "排除美国",
  "排除伊朗",
  "双向聚类"
)
dt[, test := factor(test, levels = test_order)]
dt <- dt[!is.na(test)]

plot_forest <- function(trade_sel, title_suffix) {
  d <- dt[trade == trade_sel]
  if (nrow(d) == 0) return(NULL)
  
  ggplot(d, aes(x = estimate, y = test, color = var_label)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
    geom_errorbarh(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se),
                   height = 0.25, linewidth = 0.6) +
    geom_point(size = 2.5) +
    scale_color_brewer(palette = "Set1", name = "变量") +
    labs(
      title = paste0("方向化制裁/科技管制效应稳健性：", title_suffix),
      subtitle = "控制 ISO 与 YearMonth 固定效应；误差线为 95% 置信区间",
      x = "系数（对贸易流量的弹性）",
      y = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      legend.position = "bottom",
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(linewidth = 0.2, color = "grey80"),
      plot.title = element_text(face = "bold", size = 13)
    )
}

p_imports <- plot_forest("Trade_Imports", "进口")
p_exports <- plot_forest("Trade_Exports", "出口")

if (!is.null(p_imports)) {
  ggsave(file.path(OUT_DIR, "09n_directional_sanction_robustness_imports.png"),
         p_imports, width = 9, height = 6, dpi = 300)
  cat("✓ 已保存 09n_directional_sanction_robustness_imports.png\n")
}
if (!is.null(p_exports)) {
  ggsave(file.path(OUT_DIR, "09n_directional_sanction_robustness_exports.png"),
         p_exports, width = 9, height = 6, dpi = 300)
  cat("✓ 已保存 09n_directional_sanction_robustness_exports.png\n")
}

# 如需组合图，可手动用 gridExtra::grid.arrange 拼接；此处输出分图以避免额外依赖
