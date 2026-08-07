# 09o_directional_sanction_plot_placebo.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

DRAW_PATH <- file.path(TEST_DIR, "检验结果CSV", "09m_directional_sanction_placebo_draws.csv")
SUMMARY_PATH <- file.path(TEST_DIR, "检验结果CSV", "09m_directional_sanction_placebo_summary.csv")
if (!file.exists(DRAW_PATH)) stop("请先运行 09m_directional_sanction_robustness.R 以生成安慰剂抽样结果")

draws <- fread(DRAW_PATH, encoding = "UTF-8")
setnames(draws, sub("^\ufeff", "", names(draws)))
summary_dt <- fread(SUMMARY_PATH, encoding = "UTF-8")
setnames(summary_dt, sub("^\ufeff", "", names(summary_dt)))

summary_dt[, var_label := fcase(
  variable == "Cat_科技管制_对华", "科技管制（对华）",
  variable == "Cat_经贸制裁_对华", "经贸制裁（对华）",
  default = variable
)]

draws[, var_label := fcase(
  variable == "Cat_科技管制_对华", "科技管制（对华）",
  variable == "Cat_经贸制裁_对华", "经贸制裁（对华）",
  default = variable
)]

p <- ggplot(draws[!is.na(placebo_coef)], aes(x = placebo_coef)) +
  geom_histogram(aes(y = after_stat(density)), bins = 40, fill = "steelblue", color = "white", alpha = 0.7) +
  geom_density(color = "darkblue", linewidth = 0.8) +
  geom_vline(data = summary_dt, aes(xintercept = actual_coef), color = "firebrick",
             linetype = "dashed", linewidth = 1, show.legend = FALSE) +
  geom_text(data = summary_dt,
            aes(x = actual_coef, y = Inf,
                label = sprintf("实际系数 = %.3f\n安慰剂 p = %.3f", actual_coef, placebo_pvalue)),
            hjust = 1.1, vjust = 1.5, color = "firebrick", size = 3.2,
            inherit.aes = FALSE, show.legend = FALSE) +
  facet_wrap(~var_label, scales = "free") +
  labs(
    title = "方向化制裁/科技管制的安慰剂检验",
    subtitle = "在同一个月内随机打乱事件虚拟变量；竖线为实际估计系数",
    x = "安慰剂系数",
    y = "密度"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 13),
    strip.text = element_text(face = "bold", size = 12)
  )

ggsave(file.path(OUT_DIR, "09o_directional_sanction_placebo.png"),
       p, width = 10, height = 5, dpi = 300)
cat("✓ 已保存 09o_directional_sanction_placebo.png\n")
print(summary_dt)
