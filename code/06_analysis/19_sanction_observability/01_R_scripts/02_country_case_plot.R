# 02_country_case_plot.R

pkgs <- c("data.table", "dplyr", "ggplot2", "readr")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

# ---- 路径 ----
BASE_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件/19_制裁事件进口方向可观察性检验"
IN_TABLE <- file.path(BASE_DIR, "02_输出表格")
OUT_TABLE <- file.path(BASE_DIR, "02_输出表格")
OUT_FIG <- file.path(BASE_DIR, "03_输出图片")
dir.create(OUT_FIG, recursive = TRUE, showWarnings = FALSE)

# ---- 配色与主题 ----
COL_INC <- "#D55E00"
COL_DEC <- "#0072B2"
COL_NEU <- "#999999"
COL_MED <- "#1A1A1A"
COL_INK <- "#1A1A1A"
COL_AXIS <- "#333333"

theme_sanction <- function(base_size = 10) {
  theme_classic(base_size = base_size) +
    theme(
      axis.line = element_line(linewidth = 0.4, colour = COL_AXIS),
      axis.ticks = element_line(linewidth = 0.4, colour = COL_AXIS),
      axis.title = element_text(size = 10, colour = COL_INK),
      axis.text = element_text(size = 9, colour = COL_INK),
      legend.position = "top",
      legend.title = element_blank(),
      legend.text = element_text(size = 9, colour = COL_INK),
      panel.grid = element_blank(),
      strip.background = element_blank(),
      strip.text = element_text(size = 10, face = "bold", colour = COL_INK),
      plot.tag = element_text(size = 11, face = "bold", colour = COL_INK),
      text = element_text(colour = COL_INK)
    )
}

# ---- 读取数据 ----
cat("[1/4] 读取事件变化数据...\n")
ev <- fread(file.path(IN_TABLE, "event_import_changes.csv"), encoding = "UTF-8")
setnames(ev, sub("^\ufeff", "", names(ev)))

# 转换成长格式用于绘图
plot_long <- rbind(
  ev[, .(ISO, Country, YearMonth, event_type, covid_period,
         window = "t = +1", pct_change = pct_change_1, direction = direction_1)],
  ev[, .(ISO, Country, YearMonth, event_type, covid_period,
         window = "t = +2", pct_change = pct_change_2, direction = direction_2)]
)
plot_long <- plot_long[!is.na(pct_change)]
plot_long$window <- factor(plot_long$window, levels = c("t = +1", "t = +2"))
plot_long$direction <- factor(plot_long$direction,
                              levels = c("Decrease", "No change", "Increase"))

# ---- 国家层面汇总 ----
cat("[2/4] 计算国家层面汇总...\n")
country_sum <- plot_long[, .(
  n_events = .N,
  n_increase = sum(direction == "Increase", na.rm = TRUE),
  n_decrease = sum(direction == "Decrease", na.rm = TRUE),
  median_pct_change = median(pct_change, na.rm = TRUE),
  mean_pct_change = mean(pct_change, na.rm = TRUE),
  sd_pct_change = sd(pct_change, na.rm = TRUE),
  min_pct_change = min(pct_change, na.rm = TRUE),
  max_pct_change = max(pct_change, na.rm = TRUE)
), by = .(ISO, Country)]
setorder(country_sum, -n_events, median_pct_change)

fwrite(country_sum, file.path(OUT_TABLE, "country_summary.csv"), bom = TRUE)
cat("  已保存 country_summary.csv\n")
print(country_sum)

# ---- 图 1：国家案例点图 ----
cat("[3/4] 绘制国家案例点图...\n")

# 国家按中位数变化排序
country_order <- country_sum$Country
country_order <- country_order[country_order %in% plot_long$Country]
plot_long$Country <- factor(plot_long$Country, levels = rev(country_order))

p_dot <- ggplot(plot_long, aes(x = pct_change * 100, y = Country, color = direction)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.3, color = COL_AXIS) +
  geom_point(size = 2.5, alpha = 0.85, stroke = 0.3) +
  stat_summary(fun = median, geom = "point", shape = 3, size = 3.5, color = COL_MED,
               aes(group = Country), show.legend = FALSE) +
  scale_color_manual(values = c("Increase" = COL_INC, "Decrease" = COL_DEC, "No change" = COL_NEU)) +
  scale_x_continuous(labels = function(x) paste0(x, "%"), name = "Import change relative to t = -1") +
  facet_wrap(~window, ncol = 1) +
  labs(y = NULL, tag = "a",
       title = "Country-level import changes after partner-to-China sanction events",
       subtitle = "Crosses mark country medians; baseline = one month before event") +
  theme_sanction()

fig_path_dot <- file.path(OUT_FIG, "fig_country_case_dotplot")
ggsave(paste0(fig_path_dot, ".pdf"), p_dot, width = 8, height = 7, dpi = 600, device = cairo_pdf)
ggsave(paste0(fig_path_dot, ".png"), p_dot, width = 8, height = 7, dpi = 300)
ggsave(paste0(fig_path_dot, "_preview.png"), p_dot, width = 8, height = 7, dpi = 150)
cat(sprintf("  已保存：%s\n", fig_path_dot))

# ---- 图 2：百分比变化直方图 ----
cat("[4/4] 绘制百分比变化直方图...\n")

med_t1 <- median(plot_long[window == "t = +1"]$pct_change, na.rm = TRUE) * 100
med_t2 <- median(plot_long[window == "t = +2"]$pct_change, na.rm = TRUE) * 100

p_hist <- ggplot(plot_long, aes(x = pct_change * 100, fill = direction)) +
  geom_histogram(bins = 12, color = "white", linewidth = 0.2, alpha = 0.85) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.4, color = COL_AXIS) +
  geom_vline(data = plot_long[, .(med = median(pct_change, na.rm = TRUE) * 100), by = window],
             aes(xintercept = med), linetype = "solid", linewidth = 0.8, color = COL_MED) +
  scale_fill_manual(values = c("Increase" = COL_INC, "Decrease" = COL_DEC, "No change" = COL_NEU)) +
  scale_x_continuous(labels = function(x) paste0(x, "%"), name = "Import change relative to t = -1") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05)), name = "Number of events") +
  facet_wrap(~window, ncol = 2) +
  labs(tag = "b",
       title = "Distribution of import changes around partner-to-China sanction events",
       subtitle = sprintf("Median at t=+1: %.1f%%, t=+2: %.1f%%", med_t1, med_t2)) +
  theme_sanction()

fig_path_hist <- file.path(OUT_FIG, "fig_pct_change_histogram")
ggsave(paste0(fig_path_hist, ".pdf"), p_hist, width = 8, height = 4.5, dpi = 600, device = cairo_pdf)
ggsave(paste0(fig_path_hist, ".png"), p_hist, width = 8, height = 4.5, dpi = 300)
ggsave(paste0(fig_path_hist, "_preview.png"), p_hist, width = 8, height = 4.5, dpi = 150)
cat(sprintf("  已保存：%s\n", fig_path_hist))
