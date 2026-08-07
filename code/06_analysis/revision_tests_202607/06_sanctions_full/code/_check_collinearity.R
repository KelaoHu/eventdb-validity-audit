rm(list = ls())
library(fixest)
library(data.table)

ROOT_DIR <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.3 政治经济组合分析PPMLHDFE/新PPMLHDFE"
PPML_DIR <- file.path(ROOT_DIR, "02_事件驱动PPMLHDFE")
panel_ev <- fread(file.path(PPML_DIR, "00_事件面板构建", "中间数据",
                            "event_panel_with_directional_sanctions.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

cat_cols <- grep("^Cat_", names(panel_ev), value = TRUE)
cat_cols <- cat_cols[!grepl("_L[0-9]+$|_F[0-9]+$", cat_cols)]
cat_cols <- setdiff(cat_cols, c("Cat_科技管制/出口限制", "Cat_经贸制裁/关税壁垒"))
target_vars <- c("Cat_科技管制_对华", "Cat_经贸制裁_对华")
other_dir <- c("Cat_科技管制_对伙伴", "Cat_经贸制裁_对伙伴", "Cat_经贸制裁_多边", "Cat_经贸制裁_模糊")
other_dir <- other_dir[other_dir %in% names(panel_ev)]
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")

dt <- panel_ev[YearMonth < as.Date("2020-01-01") | YearMonth > as.Date("2021-06-01")]
rhs <- c(sprintf("`%s`", target_vars), sprintf("`%s`", other_dir),
         sprintf("`%s`", cat_cols), CONTROLS, "Event_Negative")
fml <- as.formula(sprintf("Trade_Imports ~ %s | ISO + YearMonth", paste(rhs, collapse = " + ")))
fit <- fepois(fml, data = dt, cluster = ~ISO, glm.iter = 100)
cat("collin.var (removed):", paste(fit$collin.var, collapse = ", "), "\n")

# Event_Negative 与其他变量的关系：负向事件月中制裁事件占比
cat("\nEvent_Negative==1 月数:", nrow(dt[Event_Negative == 1]), "\n")
cat("科技管制_对华==1 月数:", nrow(dt[get("Cat_科技管制_对华") == 1]),
    " 其中 Event_Negative==1:", nrow(dt[get("Cat_科技管制_对华") == 1 & Event_Negative == 1]), "\n")
cat("经贸制裁_对华==1 月数:", nrow(dt[get("Cat_经贸制裁_对华") == 1]),
    " 其中 Event_Negative==1:", nrow(dt[get("Cat_经贸制裁_对华") == 1 & Event_Negative == 1]), "\n")
# 全样本
dt2 <- panel_ev
cat("\n[全样本] 科技管制_对华==1:", nrow(dt2[get("Cat_科技管制_对华") == 1]),
    " 其中 Event_Negative==1:", nrow(dt2[get("Cat_科技管制_对华") == 1 & Event_Negative == 1]), "\n")
cat("[全样本] 经贸制裁_对华==1:", nrow(dt2[get("Cat_经贸制裁_对华") == 1]),
    " 其中 Event_Negative==1:", nrow(dt2[get("Cat_经贸制裁_对华") == 1 & Event_Negative == 1]), "\n")
# 全样本回归也检查共线
fit2 <- fepois(fml, data = dt2, cluster = ~ISO, glm.iter = 100)
cat("[全样本] collin.var:", paste(fit2$collin.var, collapse = ", "), "\n")
