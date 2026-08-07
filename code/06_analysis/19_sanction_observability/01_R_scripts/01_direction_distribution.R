# 01_direction_distribution.R

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
COL_INC <- "#D55E00"   # 上升用红（冲突/意外）
COL_DEC <- "#0072B2"   # 下降用蓝
COL_NEU <- "#999999"   # 不变灰
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
cat("[1/3] 读取事件变化数据...\n")
ev <- fread(file.path(IN_TABLE, "event_import_changes.csv"), encoding = "UTF-8")
setnames(ev, sub("^\ufeff", "", names(ev)))

# ---- 构建方向分布表 ----
cat("[2/3] 计算方向分布...\n")

calc_dist <- function(dt, label) {
  n <- nrow(dt)
  if (n == 0) return(NULL)
  
  d1 <- dt[, .N, by = direction_1]
  d2 <- dt[, .N, by = direction_2]
  
  res <- data.table(
    sample = label,
    n_total = n,
    window = c("t = +1", "t = +2")
  )
  
  for (dir in c("Increase", "Decrease", "No change")) {
    n1 <- d1[direction_1 == dir, sum(N, na.rm = TRUE)]
    n2 <- d2[direction_2 == dir, sum(N, na.rm = TRUE)]
    res[[paste0("n_", tolower(gsub(" ", "_", dir)))]] <- c(n1, n2)
    res[[paste0("pct_", tolower(gsub(" ", "_", dir)))]] <- c(n1 / n * 100, n2 / n * 100)
  }
  
  # 中位数百分比变化
  med1 <- median(dt$pct_change_1, na.rm = TRUE)
  med2 <- median(dt$pct_change_2, na.rm = TRUE)
  res$median_pct_change <- c(med1, med2)
  
  # 二项检验：H0: P(Increase) = 0.5
  n_inc1 <- res$n_increase[1]
  n_inc2 <- res$n_increase[2]
  bt1 <- binom.test(n_inc1, n, p = 0.5)
  bt2 <- binom.test(n_inc2, n, p = 0.5)
  res$binom_p_increase <- c(bt1$p.value, bt2$p.value)
  res$binom_ci_lo <- c(bt1$conf.int[1], bt2$conf.int[1])
  res$binom_ci_hi <- c(bt1$conf.int[2], bt2$conf.int[2])
  
  return(res)
}

samples <- list(
  "All partner-to-China events" = ev[event_type %in% c("Tech control", "Economic sanction", "Both")],
  "Tech control only" = ev[event_type == "Tech control"],
  "Economic sanction only" = ev[event_type == "Economic sanction"],
  "Excl. COVID 2020-01~2021-06" = ev[covid_period == 0],
  "COVID 2020-01~2021-06 only" = ev[covid_period == 1]
)

dist_list <- list()
for (nm in names(samples)) {
  tmp <- calc_dist(samples[[nm]], nm)
  if (!is.null(tmp)) dist_list[[length(dist_list) + 1]] <- tmp
}
dist_tab <- rbindlist(dist_list, use.names = TRUE, fill = TRUE)

# 保存分布表
fwrite(dist_tab, file.path(OUT_TABLE, "direction_distribution.csv"), bom = TRUE)
cat("  已保存 direction_distribution.csv\n")
print(dist_tab[, .(sample, window, n_total, n_increase, pct_increase, median_pct_change, binom_p_increase)])

# ---- 绘图：方向分布柱状图 ----
cat("[3/3] 绘制方向分布图...\n")

plot_dt <- dist_tab[, .(sample, window, Increase = pct_increase, Decrease = pct_decrease, `No change` = pct_no_change)]
plot_long <- melt(plot_dt, id.vars = c("sample", "window"),
                  variable.name = "direction", value.name = "percentage")
plot_long$direction <- factor(plot_long$direction, levels = c("Increase", "No change", "Decrease"))
plot_long$sample <- factor(plot_long$sample, levels = names(samples))
plot_long$window <- factor(plot_long$window, levels = c("t = +1", "t = +2"))

p <- ggplot(plot_long, aes(x = window, y = percentage, fill = direction)) +
  geom_bar(stat = "identity", position = "stack", width = 0.7, color = "white", linewidth = 0.2) +
  geom_text(aes(label = ifelse(percentage > 5, sprintf("%.0f%%", percentage), "")),
            position = position_stack(vjust = 0.5), size = 3, color = "white", fontface = "bold") +
  scale_fill_manual(values = c("Increase" = COL_INC, "No change" = COL_NEU, "Decrease" = COL_DEC)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05)), name = "Share of events (%)") +
  facet_wrap(~sample, ncol = 2) +
  labs(x = NULL, tag = "a",
       title = "Direction of import changes around partner-to-China sanction events",
       subtitle = "Baseline = one month before event") +
  theme_sanction()

fig_path <- file.path(OUT_FIG, "fig_direction_distribution")
ggsave(paste0(fig_path, ".pdf"), p, width = 8, height = 6, dpi = 600, device = cairo_pdf)
ggsave(paste0(fig_path, ".png"), p, width = 8, height = 6, dpi = 300)
ggsave(paste0(fig_path, "_preview.png"), p, width = 8, height = 6, dpi = 150)
cat(sprintf("  已保存图片：%s\n", fig_path))
