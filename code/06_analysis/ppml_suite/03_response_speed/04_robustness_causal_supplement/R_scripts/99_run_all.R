# 99_run_all.R

rm(list = ls())

SCRIPT_DIR <- getwd()
setwd(SCRIPT_DIR)

cat("========================================\n")
cat("开始运行：稳健性与因果识别补充模块\n")
cat("========================================\n\n")

scripts <- c(
  "00_prepare_data.R",
  "01_irf_response_speed.R",
  "02_standardization_robustness.R",
  "03_window_lag_robustness.R",
  "04_event_study_did.R"
)

for (s in scripts) {
  cat(sprintf("\n>>> 正在运行：%s\n", s))
  t0 <- Sys.time()
  source(s, encoding = "UTF-8", local = new.env(parent = globalenv()))
  t1 <- Sys.time()
  cat(sprintf(">>> %s 运行完成，耗时：%.1f 秒\n", s, as.numeric(difftime(t1, t0, units = "secs"))))
}

cat("\n========================================\n")
cat("全部模块运行完成。\n")
cat("========================================\n")
