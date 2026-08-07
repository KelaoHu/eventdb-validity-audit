# 00c_build_directional_sanctions.R

rm(list = ls())

SCRIPT_DIR <- getwd()
TEST_DIR <- dirname(SCRIPT_DIR)
PPML_DIR <- dirname(TEST_DIR)
ROOT_DIR <- dirname(PPML_DIR)
source(file.path(PPML_DIR, "00_utils.R"), encoding = "UTF-8")

OUT_DIR <- file.path(TEST_DIR, "中间数据")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("[1/4] 读取事件库与经济面板...\n")
events <- load_events(ROOT_DIR)
panel <- load_panel(ROOT_DIR)

# 国家名到 ISO 映射
iso_map <- unique(panel[, .(ISO, Country)])
setnames(iso_map, "Country", "country_en")
events <- merge(events, iso_map, by = "country_en", all.x = TRUE)

cat("[2/4] 对制裁/科技管制事件做方向分类...\n")

# 仅处理两类负面事件
target_cats <- c("科技管制/出口限制", "经贸制裁/关税壁垒")
sanction_events <- events[event_category %in% target_cats]

# 标准化 event_name 为小写用于关键词匹配
sanction_events[, name_lower := tolower(event_name)]
sanction_events[, type_lower := tolower(event_type_original)]

# 关键词规则
partner_to_china_kw <- c("ban", "bans", "blocked", "blocks", "blocking", "limit", "limits", "limited", "restriction",
                         "restrictions", "restrict", "tariffs on chinese", "tariff on chinese", "duties on chinese",
                         "duty on chinese", "surtax on chinese", "surtax on chinese-made", "anti-dumping on chinese",
                         "anti-dumping investigations on chinese", "wto consultations on chinese",
                         "export controls on", "export control on", "security concerns over", "technology concerns")

china_to_partner_kw <- c("china imposes", "china suspends", "china blocks", "china launches anti-dumping",
                         "china announces anti-dumping", "china investigates", "china initiates",
                         "china restricts", "china bars", "china halts", "china bans imports")

multilateral_kw <- c("unsc resolution", "un sanctions", "un security council", "reimposes sanctions",
                     "us withdraws from jcpoa", "unilateral sanctions", "china opposes")

# 辅助函数：检查关键词匹配
check_kw <- function(text, kws) {
  any(sapply(kws, function(k) grepl(k, text, fixed = TRUE)))
}

sanction_events[, direction := NA_character_]

for (i in seq_len(nrow(sanction_events))) {
  name <- sanction_events$name_lower[i]
  type <- sanction_events$type_lower[i]
  text <- paste(name, type)
  
  # 顺序：先判定多边，再判定中国对伙伴，最后判定伙伴对华
  if (check_kw(text, multilateral_kw)) {
    sanction_events$direction[i] <- "multilateral"
  } else if (check_kw(text, china_to_partner_kw)) {
    sanction_events$direction[i] <- "china_to_partner"
  } else if (check_kw(text, partner_to_china_kw)) {
    sanction_events$direction[i] <- "partner_to_china"
  } else {
    # 默认根据 impact 和常见模式推断
    # 如果 event_type_original 包含 sanctions/policy 且不含 china imposes，多视为伙伴对华
    if (grepl("sanctions|policy|tech control|export restriction", text)) {
      sanction_events$direction[i] <- "partner_to_china"
    } else {
      sanction_events$direction[i] <- "partner_to_china"  # 经贸类默认伙伴对华（更保守）
    }
  }
}

# 手工修正个别模糊案例（基于 event_name 直接匹配）
overrides <- list(
  "China imposes barley tariffs" = "china_to_partner",
  "China suspends canola seed licences of Richardson and Viterra" = "china_to_partner",
  "US withdraws from JCPOA and reimposes sanctions; China opposes unilateral sanctions" = "multilateral",
  "UNSC Resolution 1737 sanctions on Iran (China votes in favour)" = "multilateral",
  "UNSC Resolution 1929 fourth round sanctions on Iran (China votes in favour)" = "multilateral",
  "Kimchi import dispute with South Korea" = "ambiguous",
  "Midea acquires Kuka amid technology concerns" = "ambiguous",
  "UK buys out CGN from Sizewell C nuclear project" = "partner_to_china",
  "US-China reciprocal tariff war escalates in April 2025" = "ambiguous",
  "Trade War Begins" = "ambiguous",
  "Steel/aluminum tariffs imposed" = "partner_to_china"
)

for (evt_name in names(overrides)) {
  sanction_events[event_name == evt_name, direction := overrides[[evt_name]]]
}

# 输出方向分类表
fwrite(sanction_events[, .(country_en, country_cn, event_date, event_name, event_type_original,
                           event_category, event_category_en, impact, direction)],
       file.path(OUT_DIR, "directional_sanction_events.csv"))

cat("  方向分类结果：\n")
print(sanction_events[, .N, by = .(event_category, direction)][order(event_category, direction)])

# ============================================================================
# 3. 聚合到国家-月度面板
# ============================================================================
cat("[3/4] 聚合到国家-月度面板...\n")

sanction_events[, event_date := as.Date(paste0(event_date, "-01"))]

# 生成方向化虚拟变量
agg_list <- list()
for (cat_en in c("Tech control / export restriction", "Economic sanction / tariff barrier")) {
  for (dir in c("partner_to_china", "china_to_partner", "multilateral", "ambiguous")) {
    short_cat <- ifelse(cat_en == "Tech control / export restriction", "科技管制", "经贸制裁")
    short_dir <- switch(dir,
                        "partner_to_china" = "对华",
                        "china_to_partner" = "对伙伴",
                        "multilateral" = "多边",
                        "ambiguous" = "模糊")
    var_name <- paste0("Cat_", short_cat, "_", short_dir)
    
    sub <- sanction_events[event_category_en == cat_en & direction == dir]
    if (nrow(sub) == 0) next
    
    sub_agg <- sub[!is.na(ISO), .(n = .N), by = .(ISO, event_date)]
    sub_agg[, (var_name) := 1L]
    sub_agg[, n := NULL]
    setnames(sub_agg, "event_date", "YearMonth")
    
    agg_list[[var_name]] <- sub_agg
  }
}

# 合并所有方向化变量
agg_combined <- Reduce(function(x, y) merge(x, y, by = c("ISO", "YearMonth"), all = TRUE), agg_list)
for (v in names(agg_list)) {
  if (v %in% names(agg_combined)) {
    agg_combined[is.na(get(v)), (v) := 0L]
  }
}

# ============================================================================
# 4. 合并到已有事件面板
# ============================================================================
cat("[4/4] 合并到事件面板...\n")

panel_ev <- fread(file.path(OUT_DIR, "event_panel_ready.csv"), encoding = "UTF-8")
setnames(panel_ev, sub("^\ufeff", "", names(panel_ev)))
panel_ev[, YearMonth := as.Date(YearMonth)]

panel_new <- merge(panel_ev, agg_combined, by = c("ISO", "YearMonth"), all.x = TRUE)
for (v in names(agg_list)) {
  if (v %in% names(panel_new)) {
    panel_new[is.na(get(v)), (v) := 0L]
  }
}

# 生成滞后变量（用于 IRF）
dir_vars <- names(agg_list)
if (length(dir_vars) > 0) {
  panel_new <- make_event_lags(panel_new, dir_vars, horizons = c(1, 3, 6, 12))
}

fwrite(panel_new, file.path(OUT_DIR, "event_panel_with_directional_sanctions.csv"))
cat(sprintf("✓ event_panel_with_directional_sanctions.csv 已保存 (%d 行, %d 列)\n", 
            nrow(panel_new), ncol(panel_new)))
cat(sprintf("✓ directional_sanction_events.csv 已保存 (%d 行)\n", nrow(sanction_events)))

# 打印面板中方向化变量频数
cat("  面板中方向化变量频数：\n")
for (v in dir_vars) {
  if (v %in% names(panel_new)) {
    cat(sprintf("    %s: %d\n", v, panel_new[, sum(get(v))]))
  }
}
