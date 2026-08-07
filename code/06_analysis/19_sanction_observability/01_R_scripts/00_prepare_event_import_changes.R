# 00_prepare_event_import_changes.R

pkgs <- c("data.table", "dplyr", "readr", "lubridate")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

# ---- 路径 ----
BASE_DIR <- "C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件/19_制裁事件进口方向可观察性检验"
OUT_TABLE <- file.path(BASE_DIR, "02_输出表格")
dir.create(OUT_TABLE, recursive = TRUE, showWarnings = FALSE)

PANEL_PATH <- "C:/Users/胡克劳/Desktop/311工程数据/03_检验与分析套件/PPML套件/02_事件驱动PPMLHDFE/00_事件面板构建/中间数据/event_panel_with_directional_sanctions.csv"

# ---- 读取面板 ----
cat("[1/3] 读取事件面板...\n")
panel <- fread(PANEL_PATH, encoding = "UTF-8")
setnames(panel, sub("^\ufeff", "", names(panel)))
panel[, YearMonth := as.Date(YearMonth)]
panel[, ISO := as.character(ISO)]
panel[, Country := as.character(Country)]
setorder(panel, ISO, YearMonth)

# 目标变量（对华方向）
target_vars <- c("Cat_科技管制_对华", "Cat_经贸制裁_对华")
if (!all(target_vars %in% names(panel))) {
  stop("目标变量不存在：", paste(setdiff(target_vars, names(panel)), collapse = ", "))
}

# ---- 提取事件前后进口值 ----
cat("[2/3] 提取事件前后进口变化...\n")

event_rows <- panel[get(target_vars[1]) == 1 | get(target_vars[2]) == 1]
cat(sprintf("  对华制裁/科技管制 treated 国家-月份数：%d\n", nrow(event_rows)))

# 检查同一国家-月份是否两类事件同时发生
both <- event_rows[get(target_vars[1]) == 1 & get(target_vars[2]) == 1]
if (nrow(both) > 0) {
  cat(sprintf("  警告：%d 个国家-月份同时发生科技管制与经贸制裁事件\n", nrow(both)))
}

# 为每个 treated row 提取 t-1, t+1, t+2 的进口值
results <- list()
for (i in seq_len(nrow(event_rows))) {
  iso <- event_rows$ISO[i]
  ym  <- event_rows$YearMonth[i]
  country <- event_rows$Country[i]
  
  sub <- panel[ISO == iso]
  sub <- sub[order(YearMonth)]
  
  # 找到事件月在子集中的位置
  pos <- which(sub$YearMonth == ym)
  if (length(pos) == 0) next
  pos <- pos[1]
  n <- nrow(sub)
  
  get_imp <- function(offset) {
    idx <- pos + offset
    if (idx >= 1 && idx <= n) {
      return(sub$Trade_Imports[idx])
    } else {
      return(NA_real_)
    }
  }
  
  imp_m1 <- get_imp(-1)
  imp_p1 <- get_imp(1)
  imp_p2 <- get_imp(2)
  
  tech <- event_rows[[target_vars[1]]][i]
  sanc <- event_rows[[target_vars[2]]][i]
  
  # 事件类型标签
  if (tech == 1 && sanc == 1) {
    ev_type <- "Both"
  } else if (tech == 1) {
    ev_type <- "Tech control"
  } else {
    ev_type <- "Economic sanction"
  }
  
  # 疫情期标记
  covid_flag <- as.integer(ym >= as.Date("2020-01-01") & ym <= as.Date("2021-06-01"))
  
  results[[length(results) + 1]] <- data.table(
    ISO = iso,
    Country = country,
    YearMonth = ym,
    event_type = ev_type,
    covid_period = covid_flag,
    Import_t_minus1 = imp_m1,
    Import_t_plus1 = imp_p1,
    Import_t_plus2 = imp_p2
  )
}

out <- rbindlist(results, use.names = TRUE, fill = TRUE)

# 计算变化量与百分比变化
out[, delta_1 := Import_t_plus1 - Import_t_minus1]
out[, delta_2 := Import_t_plus2 - Import_t_minus1]
out[, pct_change_1 := ifelse(!is.na(Import_t_minus1) & Import_t_minus1 != 0,
                              delta_1 / Import_t_minus1, NA_real_)]
out[, pct_change_2 := ifelse(!is.na(Import_t_minus1) & Import_t_minus1 != 0,
                              delta_2 / Import_t_minus1, NA_real_)]

# 方向分类
out[, direction_1 := ifelse(is.na(delta_1), NA_character_,
                             ifelse(delta_1 > 0, "Increase",
                                    ifelse(delta_1 < 0, "Decrease", "No change")))]
out[, direction_2 := ifelse(is.na(delta_2), NA_character_,
                             ifelse(delta_2 > 0, "Increase",
                                    ifelse(delta_2 < 0, "Decrease", "No change")))]

# QA 打印关键数字
cat("[3/3] QA 关键数字...\n")
cat(sprintf("  总事件-国家-月观测数：%d\n", nrow(out)))
cat(sprintf("  t=-1 进口值可用：%d\n", sum(!is.na(out$Import_t_minus1))))
cat(sprintf("  t=+1 进口值可用：%d\n", sum(!is.na(out$Import_t_plus1))))
cat(sprintf("  t=+2 进口值可用：%d\n", sum(!is.na(out$Import_t_plus2))))
cat("  事件类型分布：\n")
print(out[, .N, by = event_type][order(-N)])
cat("  方向分布 t=+1：\n")
print(out[, .N, by = direction_1][order(-N)])

# 保存
out_path <- file.path(OUT_TABLE, "event_import_changes.csv")
fwrite(out, out_path, bom = TRUE)
cat(sprintf("\n已保存：%s\n", out_path))
