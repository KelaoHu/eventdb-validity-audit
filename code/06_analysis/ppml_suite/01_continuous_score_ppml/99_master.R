# 99_master.R

cat("=" ,rep("=", 69), "\n", sep = "")
cat("01 连续分数 PPML：全部分析\n")
cat("=" ,rep("=", 69), "\n\n", sep = "")

# ---- 01 基准传导 ----
cat("[01/13] 01_基准传导_季度冲击：生成 IRF 与 scaling...\n")
setwd("01_基准传导_季度冲击/R语言工程文件")
source("01_run_irf.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[02/13] 01_基准传导_季度冲击：绘制 aggregate IRF 图...\n")
setwd("01_基准传导_季度冲击/R语言工程文件")
source("01_plot_irf_aggregate.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 02 方向分解 ----
cat("\n[03/13] 02_方向分解：生成方向分解 CSV...\n")
setwd("02_方向分解/R语言工程文件")
source("02_generate_directional_csv.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[04/13] 02_方向分解：绘制方向分解图...\n")
setwd("02_方向分解/R语言工程文件")
source("02_plot_directional_decomp.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 03 干净面板 PPML ----
cat("\n[05/13] 03_干净面板PPML：生成回归结果...\n")
setwd("03_干净面板PPML/R语言工程文件")
source("03_run_clean_panel_ppml.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[06/13] 03_干净面板PPML：绘制系数图...\n")
setwd("03_干净面板PPML/R语言工程文件")
source("03_plot_clean_panel.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 04 AR1 残差回归 ----
cat("\n[07/13] 04_AR1残差回归：生成回归结果...\n")
setwd("04_AR1残差回归/R语言工程文件")
source("04_run_ar1_residual_ppml.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[08/13] 04_AR1残差回归：绘制系数图...\n")
setwd("04_AR1残差回归/R语言工程文件")
source("04_plot_ar1_residual.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 05 频率响应扫描 ----
cat("\n[09/13] 05_频率响应扫描：生成扫描结果...\n")
setwd("05_频率响应扫描/R语言工程文件")
source("05_run_freq_scan.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[10/13] 05_频率响应扫描：绘制扫描图...\n")
setwd("05_频率响应扫描/R语言工程文件")
source("05_plot_freq_scan.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 06 前向效应 ----
cat("\n[11/13] 06_前向效应：生成领先滞后结果...\n")
setwd("06_前向效应/R语言工程文件")
source("06_run_forward_effects.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n[12/13] 06_前向效应：绘制领先滞后图...\n")
setwd("06_前向效应/R语言工程文件")
source("06_plot_forward_effects.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

# ---- 07 信噪比效应量标度律 ----
cat("\n[13/13] 07_信噪比效应量标度律：绘制 rho 对比图...\n")
setwd("07_信噪比效应量标度律/R语言工程文件")
source("03_plot_scaling.R", encoding = "UTF-8", chdir = TRUE)
setwd("../..")

cat("\n=========================\n")
cat("07 连续分数 PPML 全部分析完成\n")
cat("=========================\n")
