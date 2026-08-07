# 99_master.R — 一键运行 02_事件驱动PPMLHDFE 全部分析

cat("=" ,rep("=", 69), "\n", sep = "")
cat("02 事件驱动 PPMLHDFE：全部分析\n")
cat("=" ,rep("=", 69), "\n\n", sep = "")

# ---- 00 事件面板构建 ----
cat("[01/20] 00_事件面板构建：生成 event_panel_ready.csv...\n")
setwd("00_事件面板构建/R语言工程文件")
source("00_build_event_panel.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 00c 方向化制裁面板 ----
cat("\n[02/20] 00_事件面板构建：生成方向化制裁/科技管制变量...\n")
setwd("00_事件面板构建/R语言工程文件")
source("00c_build_directional_sanctions.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 01 事件基准效应 ----
cat("\n[03/20] 01_事件基准效应：生成回归结果...\n")
setwd("01_事件基准效应/R语言工程文件")
source("01_run_baseline_ppml.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[04/20] 01_事件基准效应：绘制森林图...\n")
setwd("01_事件基准效应/R语言工程文件")
source("01_plot_baseline_effects.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 02 正负向非对称与 4 类访问效应 ----
cat("\n[05/20] 02_正负向非对称与4类访问效应：生成回归结果...\n")
setwd("02_正负向非对称与4类访问效应/R语言工程文件")
source("02_run_valence_and_visits.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[06/20] 02_正负向非对称与4类访问效应：绘制图表...\n")
setwd("02_正负向非对称与4类访问效应/R语言工程文件")
source("02_plot_valence_and_visits.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 03 17 类事件异质性 ----
cat("\n[07/20] 03_17类事件异质性：生成回归结果...\n")
setwd("03_17类事件异质性/R语言工程文件")
source("03_run_seventeen_categories.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[08/20] 03_17类事件异质性：绘制图表...\n")
setwd("03_17类事件异质性/R语言工程文件")
source("03_plot_seventeen_categories.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 04 国家异质性 ----
cat("\n[09/20] 04_国家异质性：生成回归结果...\n")
setwd("04_国家异质性/R语言工程文件")
source("04_run_country_heterogeneity.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[10/20] 04_国家异质性：绘制图表...\n")
setwd("04_国家异质性/R语言工程文件")
source("04_plot_country_heterogeneity.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 05 事件动态 IRF ----
cat("\n[11/20] 05_事件动态IRF：生成 IRF 结果...\n")
setwd("05_事件动态IRF/R语言工程文件")
source("05_run_event_irf.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[12/20] 05_事件动态IRF：绘制 IRF 图...\n")
setwd("05_事件动态IRF/R语言工程文件")
source("05_plot_event_irf.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 06 事件强度与四库验证 ----
cat("\n[13/20] 06_事件强度与四库验证：生成回归结果...\n")
setwd("06_事件强度与四库验证/R语言工程文件")
source("06_run_event_intensity.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[14/20] 06_事件强度与四库验证：绘制图表...\n")
setwd("06_事件强度与四库验证/R语言工程文件")
source("06_plot_event_intensity.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 07 稳健性与安慰剂 ----
cat("\n[15/20] 07_稳健性与安慰剂：生成检验结果...\n")
setwd("07_稳健性与安慰剂/R语言工程文件")
source("07_run_robustness_and_placebo.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[16/20] 07_稳健性与安慰剂：绘制图表...\n")
setwd("07_稳健性与安慰剂/R语言工程文件")
source("07_plot_robustness_and_placebo.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 08 汇总报告 ----
cat("\n[17/20] 08_汇总报告与可视化：生成 report.md...\n")
setwd("08_汇总报告与可视化/R语言工程文件")
source("08_generate_report.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 09 事件类型深度稳健性与动态分析 ----
cat("\n[18/20] 09_事件类型深度稳健性与动态分析：生成回归结果与图表（09a–09o）...\n")
setwd("09_事件类型深度稳健性与动态分析/R语言工程文件")
source("09a_reliability_seventeen_categories.R", encoding = "UTF-8", chdir = TRUE)
source("09b_mechanism_economic_cooperation.R", encoding = "UTF-8", chdir = TRUE)
source("09c_robustness_economic_cooperation.R", encoding = "UTF-8", chdir = TRUE)
source("09d_irf_key_categories.R", encoding = "UTF-8", chdir = TRUE)
source("09e_subsample_heterogeneity.R", encoding = "UTF-8", chdir = TRUE)
source("09j_directional_sanction_import_response.R", encoding = "UTF-8", chdir = TRUE)
source("09k_directional_sanction_irf.R", encoding = "UTF-8", chdir = TRUE)
source("09l_directional_sanction_country_response.R", encoding = "UTF-8", chdir = TRUE)
source("09m_directional_sanction_robustness.R", encoding = "UTF-8", chdir = TRUE)
source("09n_directional_sanction_plot_robustness.R", encoding = "UTF-8", chdir = TRUE)
source("09o_directional_sanction_plot_placebo.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 10 国家敏感度差异检验 ----
cat("\n[19/20] 10_国家敏感度差异检验：生成回归结果（10a–10e）...\n")
setwd("10_国家敏感度差异检验/R语言工程文件")
source("10a_country_sensitivity_interactions_and_jackknife.R", encoding = "UTF-8", chdir = TRUE)
source("10b_country_sensitivity_meta_regression.R", encoding = "UTF-8", chdir = TRUE)
source("10c_country_label_placebo.R", encoding = "UTF-8", chdir = TRUE)
source("10d_group_irf_cumulative_sensitivity.R", encoding = "UTF-8", chdir = TRUE)
source("10e_cross_database_sensitivity_validation.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[20/20] 全部完成。\n")
cat("=========================\n")
cat("02 事件驱动 PPMLHDFE 全部分析完成\n")
cat("=========================\n")
