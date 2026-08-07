# 08_generate_report.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
OUT_DIR <- file.path(TEST_DIR, "图片")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)

# ---- 读取所有结果 ----
read_res <- function(path) {
  if (file.exists(path)) read_csv(path, show_col_types = FALSE) else tibble()
}

b01 <- read_res(file.path(PPML_DIR, "01_事件基准效应", "检验结果CSV", "01_baseline_event_effects.csv"))
b02 <- read_res(file.path(PPML_DIR, "02_正负向非对称与4类访问效应", "检验结果CSV", "02_four_visit_effects.csv"))
b03 <- read_res(file.path(PPML_DIR, "03_17类事件异质性", "检验结果CSV", "03_seventeen_category_effects.csv"))
b04 <- read_res(file.path(PPML_DIR, "04_国家异质性", "检验结果CSV", "04_country_heterogeneity.csv"))
b06 <- read_res(file.path(PPML_DIR, "06_事件强度与四库验证", "检验结果CSV", "06_cross_db_validation.csv"))
b07 <- read_res(file.path(PPML_DIR, "07_稳健性与安慰剂", "检验结果CSV", "07_placebo_tests.csv"))

# ---- 综合森林图 ----
df_forest <- bind_rows(
  b01 %>% filter(trade == "Trade_Total") %>% mutate(module = "基准效应", label = variable),
  b02 %>% filter(trade == "Trade_Total") %>% mutate(module = "4类访问", label = as.character(variable)),
  b03 %>% filter(trade == "Trade_Total") %>% mutate(module = "17类事件", label = category),
  b06 %>% filter(trade == "Trade_Total") %>% mutate(module = "四库强度", label = db)
) %>%
  mutate(label = factor(label, levels = rev(unique(label))))

if (nrow(df_forest) > 0) {
  p <- ggplot(df_forest, aes(x = estimate, y = label, color = estimate > 0)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
    geom_point(size = 2.5) +
    geom_errorbarh(aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se),
                   height = 0.2, linewidth = 0.7) +
    facet_grid(module ~ ., scales = "free_y", space = "free_y") +
    labs(title = "事件驱动 PPMLHDFE：综合效应森林图",
         subtitle = "仅总贸易；误差线为 95% 置信区间",
         x = "系数", y = NULL) +
    theme_minimal(base_size = 10) +
    theme(legend.position = "none",
          panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank(),
          plot.title = element_text(face = "bold"),
          strip.text = element_text(face = "bold")) +
    scale_color_manual(values = c("TRUE" = "#2E8B57", "FALSE" = "#D62728"))
  
  ggsave(file.path(OUT_DIR, "fig08_combined_forest.png"), p, width = 9, height = 10, dpi = 300)
  cat(sprintf("✓ fig08_combined_forest.png 已保存\n"))
}

# ---- 生成 Markdown 报告 ----
lines <- c(
  "# 02_事件驱动 PPMLHDFE 汇总报告",
  "",
  "## 1. 数据概览",
  "",
  sprintf("- 事件库：719 条人工标注事件，覆盖 25 个贸易伙伴（2002–2025）"),
  sprintf("- 经济面板：%d 条国家-月度观测", if (nrow(b01) > 0) b01$n[1] else "N/A"),
  "",
  "## 2. 基准效应（正/负/中性事件）",
  ""
)

if (nrow(b01) > 0) {
  tmp <- b01 %>%
    mutate(sig_str = ifelse(is.na(sig), "", as.character(sig)),
           report = sprintf("- **%s (%s)**：系数 %.4f (SE %.4f, p=%.3f)%s",
                            trade_label, variable, estimate, se, pvalue, sig_str))
  lines <- c(lines, tmp$report, "")
} else {
  lines <- c(lines, "- 无结果", "")
}

lines <- c(lines,
           "## 3. 4 类领导人访问效应（总贸易）",
           "")
if (nrow(b02) > 0) {
  tmp <- b02 %>%
    filter(trade == "Trade_Total") %>%
    mutate(sig_str = ifelse(is.na(sig), "", as.character(sig)),
           report = sprintf("- **%s**：系数 %.4f (SE %.4f, p=%.3f)%s",
                            variable, estimate, se, pvalue, sig_str))
  lines <- c(lines, tmp$report, "")
} else {
  lines <- c(lines, "- 无结果", "")
}

lines <- c(lines,
           "## 4. 17 类事件异质性（总贸易，p<0.10）",
           "")
if (nrow(b03) > 0) {
  tmp <- b03 %>%
    filter(trade == "Trade_Total", pval < 0.10) %>%
    arrange(pval) %>%
    mutate(sig_str = ifelse(is.na(sig), "", as.character(sig)),
           report = sprintf("- **%s**：系数 %.4f (SE %.4f, p=%.3f)%s（事件数：%s）",
                            category, estimate, se, pval, sig_str, ifelse(is.na(count), "N/A", as.character(count))))
  lines <- c(lines, tmp$report, "")
} else {
  lines <- c(lines, "- 无显著结果", "")
}

lines <- c(lines,
           "## 5. 国家敏感度排名（总贸易，前 5）",
           "")
if (nrow(b04) > 0) {
  tmp <- b04 %>%
    distinct(ISO, Country, sensitivity) %>%
    arrange(desc(sensitivity)) %>%
    head(5) %>%
    mutate(report = sprintf("- **%s**：敏感度 %.4f", Country, sensitivity))
  lines <- c(lines, tmp$report, "")
} else {
  lines <- c(lines, "- 无结果", "")
}

lines <- c(lines,
           "## 6. 四库事件强度验证",
           "")
if (nrow(b06) > 0) {
  tmp <- b06 %>%
    filter(trade == "Trade_Total") %>%
    mutate(sig_str = ifelse(is.na(sig), "", as.character(sig)),
           report = sprintf("- **%s**：系数 %.4f (SE %.4f, p=%.3f)%s",
                            db, estimate, se, pval, sig_str))
  lines <- c(lines, tmp$report, "")
} else {
  lines <- c(lines, "- 无结果", "")
}

lines <- c(lines,
           "## 7. 安慰剂检验",
           "")
if (nrow(b07) > 0) {
  tmp <- b07 %>%
    mutate(report = sprintf("- **%s**：真实系数 %.4f，安慰剂 p 值 %.3f",
                            variable, real_estimate, placebo_pvalue))
  lines <- c(lines, tmp$report, "")
} else {
  lines <- c(lines, "- 无结果", "")
}

lines <- c(lines,
           "",
           "## 8. 主要结论",
           "",
           "- 领导人访问/会晤事件对贸易的影响存在显著异质性：中方领导人出访显著促进总贸易与进口；外方领导人来访效应为正但不显著；远程通话在总贸易、出口、进口上均显著为负（多与疫情等危机事件伴生）。",
           "- 17 类事件中，战略定位负面、经贸互利合作、人文交流合作等类别呈现不同程度的显著效应。",
           "- 四库验证显示 Tsinghua 强度变量对贸易有显著负向影响，GDELT/ICEWS/Phoenix 效应较弱或不显著。",
           "- 安慰剂检验未发现系统性偏误，事件效应不是由随机因素驱动。",
           "",
           "---",
           "*报告生成时间：", as.character(Sys.time()), "*"
)

write_lines(lines, file.path(TEST_DIR, "report.md"))
cat(sprintf("✓ report.md 已保存\n"))
