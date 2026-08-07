# 09b_plot_fta_event_study.R — FTA 事件研究系数图（英文标注，300dpi）

rm(list = ls())
library(data.table)
library(ggplot2)

OUT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/修订补充检验_202607/09_FTA基准效应"
dt <- fread(file.path(OUT_DIR, "results", "fta_event_study.csv"), encoding = "UTF-8")
dt[, Outcome := factor(trade, levels = c("Trade_Total", "Trade_Exports", "Trade_Imports"),
                       labels = c("Total trade", "Exports", "Imports"))]

p <- ggplot(dt, aes(x = k, y = coef, color = Outcome, fill = Outcome)) +
  annotate("rect", xmin = -0.5, xmax = 12.5, ymin = -Inf, ymax = Inf,
           alpha = 0.06, fill = "grey30") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.4) +
  geom_vline(xintercept = -0.5, linetype = "solid", color = "grey30", linewidth = 0.5) +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.8) +
  scale_x_continuous(breaks = seq(-6, 12, 2)) +
  scale_color_manual(values = c("Total trade" = "#1B9E77", "Exports" = "#D95F02", "Imports" = "#7570B3")) +
  scale_fill_manual(values = c("Total trade" = "#1B9E77", "Exports" = "#D95F02", "Imports" = "#7570B3")) +
  labs(title = "Event-study estimates around FTA entry into force",
       subtitle = paste0("PPML-HDFE, monthly dummies k = -6..+12 (base k = -7); 8 in-sample FTA activations ",
                         "(ID/PH/SG/TH/VN 2007-07, AU/KR 2015-12, JP 2022-01); 16 never-treated controls"),
       x = "Months relative to FTA entry into force", y = "Coefficient (log points)",
       caption = "Note: Country + Year-Month FE; two-way clustered (country & year-month) 95% CI.\nMalaysia excluded (FTA active from its first panel observation). Shaded area = post-entry window.") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title = element_text(size = 12, face = "bold"),
        plot.subtitle = element_text(size = 8.5),
        plot.caption = element_text(size = 8, hjust = 0))

ggsave(file.path(OUT_DIR, "figures", "fta_event_study.png"), p, width = 9.5, height = 6, dpi = 300)
cat("✓ fta_event_study.png 已保存\n")
