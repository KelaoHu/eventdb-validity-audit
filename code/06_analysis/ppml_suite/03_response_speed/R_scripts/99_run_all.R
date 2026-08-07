# 99_run_all.R

rm(list = ls())

cat("=" ,rep("=", 69), "\n", sep = "")
cat("03_响应速度复现：全部分析\n")
cat("=" ,rep("=", 69), "\n\n", sep = "")

SCRIPT_DIR <- getwd()

run_step <- function(step_name, file_name) {
  cat(sprintf("\n[%s] %s\n", step_name, file_name))
  source(file_name, encoding = "UTF-8", chdir = TRUE, local = TRUE)
}

run_step("01/04", "00_prepare_data.R")
run_step("02/04", "01_run_rolling_window.R")
run_step("03/04", "02_compute_response_speed.R")
run_step("04/04", "03_plot_response_speed.R")

cat("\n=========================\n")
cat("03_响应速度复现 全部完成\n")
cat("=========================\n")
