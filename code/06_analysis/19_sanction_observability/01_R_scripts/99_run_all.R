# 99_run_all.R

rm(list = ls())

SCRIPT_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件/19_制裁事件进口方向可观察性检验/01_R脚本"

cat("============================================================\n")
cat("制裁事件进口方向可观察性检验\n")
cat("============================================================\n\n")

cat("[Step 1/3] 提取事件前后进口变化...\n")
source(file.path(SCRIPT_DIR, "00_prepare_event_import_changes.R"), encoding = "UTF-8")

cat("\n[Step 2/3] 方向分布统计与柱状图...\n")
source(file.path(SCRIPT_DIR, "01_direction_distribution.R"), encoding = "UTF-8")

cat("\n[Step 3/3] 国家层面点图与直方图...\n")
source(file.path(SCRIPT_DIR, "02_country_case_plot.R"), encoding = "UTF-8")

cat("\n============================================================\n")
cat("全部完成。输出见：\n")
cat("  - 表格：C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件/19_制裁事件进口方向可观察性检验/02_输出表格/\n")
cat("  - 图片：C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件/19_制裁事件进口方向可观察性检验/03_输出图片/\n")
cat("============================================================\n")
