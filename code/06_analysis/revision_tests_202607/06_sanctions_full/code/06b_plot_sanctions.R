# 06b_plot_sanctions.R — 制裁三维度系数对比图（英文标注，300dpi）

rm(list = ls())
library(data.table)
library(ggplot2)

OUT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/06_制裁三维度完整报告"
dt <- fread(file.path(OUT_DIR, "results", "sanctions_full_table.csv"), encoding = "UTF-8")

dt[, Sample := ifelse(sample == "全样本", "Full sample", "Excl. COVID (2020.01-2021.06)")]
dt[, Specification := ifelse(spec == "基准仅17类控制", "Baseline (17-cat controls)", "+ Event_Negative")]
dt[, Event := ifelse(variable == "Cat_科技管制_对华", "Tech control vs China", "Economic sanction vs China")]
dt[, Outcome := factor(trade, levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                       labels = c("Total trade", "Exports", "Imports"))]
dt[, ci_lo := coef - 1.96 * se]
dt[, ci_hi := coef + 1.96 * se]

p <- ggplot(dt, aes(x = Outcome, y = coef, color = Specification, shape = Specification)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.4) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.18, linewidth = 0.6,
                position = position_dodge(width = 0.5)) +
  geom_point(size = 2.4, position = position_dodge(width = 0.5)) +
  facet_grid(Sample ~ Event) +
  scale_color_manual(values = c("Baseline (17-cat controls)" = "#2166AC",
                                "+ Event_Negative" = "#B2182B")) +
  labs(title = "Directional sanction / tech-control events and China's bilateral trade",
       subtitle = "PPML-HDFE coefficients with 95% CI (Country + Year-Month FE, clustered by country)",
       x = NULL, y = "Coefficient (log points)",
       caption = "Note: In the COVID-excluded sample Event_Negative is perfectly collinear and dropped;\nthe '+ Event_Negative' spec is then unidentified and identical to the baseline.") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title = element_text(size = 12, face = "bold"),
        plot.subtitle = element_text(size = 9.5),
        plot.caption = element_text(size = 8, hjust = 0),
        strip.text = element_text(size = 9.5))

ggsave(file.path(OUT_DIR, "figures", "sanctions_coef_plot.png"), p,
       width = 9, height = 7, dpi = 300)
cat("✓ sanctions_coef_plot.png 已保存\n")
