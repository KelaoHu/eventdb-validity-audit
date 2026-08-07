# 00_utils.R

# ---- 包加载 ----
pkgs <- c("fixest", "data.table", "dplyr", "readr", "tidyr", "ggplot2", "stringr", "lubridate")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org/")
    library(p, character.only = TRUE)
  }
}

# ---- 路径解析（兼容 source/chdir 和直接 Rscript 运行） ----
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  f <- grep("^--file=", args, value = TRUE)
  if (length(f) > 0) {
    path <- sub("^--file=", "", f[1])
    path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (file.exists(path)) return(dirname(path))
  }
  return(getwd())
}

# ---- 读取经济面板 ----
load_panel <- function(root_dir) {
  data_dir <- file.path(root_dir, "data")
  panel <- fread(file = file.path(data_dir, "panel_clean.csv"), encoding = "UTF-8")
  setnames(panel, sub("^\ufeff", "", names(panel)))
  panel[, month := as.Date(month)]
  panel[, YearMonth := month]
  panel[, Country := as.character(Country)]
  panel[, ISO := as.character(ISO)]
  return(panel)
}

# ---- 读取 712 事件库并清洗 ----
load_events <- function(root_dir) {
  event_file <- file.path(root_dir, "..", "..", "3.2 双边关系分析基于月度政治分数", "自建事件库_25国_17类_712条事件.csv")
  event_file <- normalizePath(event_file, winslash = "/")
  ev <- fread(file = event_file, encoding = "UTF-8")
  setnames(ev, sub("^\ufeff", "", names(ev)))
  ev[, country_en := as.character(country_en)]
  ev[, event_date := as.character(event_date)]
  ev[, YearMonth := as.Date(paste0(event_date, "-01"))]
  ev[, impact := tolower(as.character(impact))]
  ev[, event_category := as.character(event_category)]
  ev[, event_category_en := as.character(event_category_en)]
  ev[, event_type_original := as.character(event_type_original)]
  ev[, visit_level := as.character(visit_level)]
  ev[, visit_direction := as.character(visit_direction)]
  
  # 清洗 event_category：把脏英文映射回标准 17 类中文
  ev[, event_category := clean_event_category(event_category, event_type_original, event_name)]
  ev[, event_category_en := map_category_cn2en(event_category)]
  
  return(ev)
}

# 标准 17 类中文
CATEGORY_CN <- c(
  "高层互访", "多边/第三方会晤", "经贸互利合作", "战略伙伴关系提升",
  "主权纠纷", "经贸制裁/关税壁垒", "远程通话/视频会晤", "人文交流合作",
  "外交抗议/摩擦", "疫情/危机援助", "军事安全合作", "科技管制/出口限制",
  "疫情/灾害冲击", "人员扣押/司法争议", "政策转向/国内政治", "战略定位负面",
  "安全威胁"
)

# 中文 → 英文映射
CATEGORY_MAP <- data.table(
  cn = CATEGORY_CN,
  en = c(
    "High-level visit", "Multilateral / third-party meeting", "Economic win-win cooperation",
    "Strategic partnership upgrade", "Sovereignty dispute", "Economic sanction / tariff barrier",
    "Remote talk / virtual meeting", "Cultural / people-to-people cooperation",
    "Diplomatic protest / friction", "Pandemic / crisis aid", "Military / security cooperation",
    "Tech control / export restriction", "Pandemic / disaster shock", "Detention / judicial dispute",
    "Policy shift / domestic politics", "Negative strategic positioning", "Security threat"
  )
)

clean_event_category <- function(cat_vec, type_vec, name_vec) {
  cat_vec <- trimws(as.character(cat_vec))
  type_vec <- tolower(trimws(as.character(type_vec)))
  name_vec <- tolower(trimws(as.character(name_vec)))
  
  out <- sapply(seq_along(cat_vec), function(i) {
    c <- cat_vec[i]
    t <- type_vec[i]
    n <- name_vec[i]
    
    if (!is.na(c) && c %in% CATEGORY_CN) return(c)
    
    # 脏值英文映射
    if (is.na(c) || c == "" || c %in% c("leader_visit", "economic", "diplomatic", "strategic", "territorial", "military", "sanctions", "policy", "pandemic", "crisis")) {
      if (grepl("visit|summit|meet|talk", t) || grepl("visit|summit|meet|talk", n)) {
        # 区分第三方会晤
        if (grepl("apec|g20|brics|asean|un|third|sideline", n)) return("多边/第三方会晤")
        return("高层互访")
      }
      if (grepl("economic|trade|fta|invest|cooperation|agreement", t) || grepl("economic|trade|fta|invest|cooperation|agreement", n)) {
        if (grepl("sanction|tariff|ban|restrict|barrier", n)) return("经贸制裁/关税壁垒")
        return("经贸互利合作")
      }
      if (grepl("territorial|sovereign|border|island|sea", t) || grepl("territorial|sovereign|diaoyu|south china|east china|xinjiang|tibet", n)) return("主权纠纷")
      if (grepl("military|security|defense|threat|weapon|nuclear", t) || grepl("military|security|defense|weapon|nuclear|aukus|quad", n)) return("安全威胁")
      if (grepl("diplomatic|protest|friction|condemn", t) || grepl("protest|condemn|accuse|urge|statement|friction", n)) return("外交抗议/摩擦")
      if (grepl("pandemic|covid|virus|vaccine|aid", t) || grepl("covid|vaccine|aid|medical|pandemic", n)) {
        if (grepl("aid|vaccine|medical|assist", n)) return("疫情/危机援助")
        return("疫情/灾害冲击")
      }
      if (grepl("strategic|partnership|upgrade", t) || grepl("strategic|comprehensive|partnership", n)) return("战略伙伴关系提升")
      if (grepl("policy|law|legislation|domestic", t) || grepl("law|legislation|domestic|interference", n)) return("政策转向/国内政治")
      if (grepl("tech|huawei|5g|semiconductor|export control", t) || grepl("huawei|5g|tech|semiconductor|chip|export control", n)) return("科技管制/出口限制")
      if (grepl("detain|arrest|judicial|court", t) || grepl("detain|arrest|judicial|court|sentence", n)) return("人员扣押/司法争议")
      return("外交抗议/摩擦")  # 缺省兜底
    }
    return(c)
  })
  return(out)
}

map_category_cn2en <- function(cat_vec) {
  dt <- data.table(cn = cat_vec)
  dt[CATEGORY_MAP, en := i.en, on = "cn"]
  dt[is.na(en), en := cn]
  return(dt$en)
}

# ---- 读取并整理四库政治分数 ----
load_scores <- function(root_dir) {
  score_dir <- file.path(root_dir, "..", "..", "3.2 双边关系分析基于月度政治分数", "全新事件研究法", "data")
  score_dir <- normalizePath(score_dir, winslash = "/")
  
  read_score_long <- function(csv, db_name) {
    dt <- fread(file = csv, encoding = "UTF-8")
    setnames(dt, sub("^\ufeff", "", names(dt)))
    dt[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
    dt <- dcast(dt, Partner + YearMonth ~ Index_Type, value.var = "Index_Value")
    setnames(dt, c("Aggregated", "CHN->Partner", "Partner->CHN"),
             c("Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"), skip_absent = TRUE)
    dt[, db := db_name]
    dt[, Country := Partner]
    return(dt[, !"Partner"])
  }
  
  gdelt <- read_score_long(file.path(score_dir, "gdelt_scores.csv"), "GDELT")
  icews <- read_score_long(file.path(score_dir, "icews_scores.csv"), "ICEWS")
  phoenix <- read_score_long(file.path(score_dir, "phoenix_scores.csv"), "Phoenix")
  
  tsinghua <- fread(file = file.path(score_dir, "tsinghua_scores.csv"), encoding = "UTF-8")
  setnames(tsinghua, sub("^\ufeff", "", names(tsinghua)))
  tsinghua[, YearMonth := as.Date(paste0(YearMonth, "-01"))]
  setnames(tsinghua, c("Country", "YearMonth", "Score"), c("Country", "YearMonth", "Pol_Agg"))
  tsinghua[, db := "Tsinghua"]
  
  scores <- rbindlist(list(gdelt, icews, phoenix, tsinghua), fill = TRUE, use.names = TRUE)
  return(scores)
}

# ---- 构建事件面板 ----
build_event_panel <- function(panel, events, scores = NULL) {
  # 生成正/负/中性指示
  events[, Event_Positive := as.integer(impact == "positive")]
  events[, Event_Negative := as.integer(impact == "negative")]
  events[, Event_Neutral := as.integer(impact == "neutral")]
  
  # 生成 4 类访问指示（合并 state_head / government_head）
  events[, visit_direction := ifelse(is.na(visit_direction), "", visit_direction)]
  events[, visit_level := ifelse(is.na(visit_level), "", visit_level)]
  events[, V_RemoteTalk := as.integer(grepl("Remote talk", event_category_en))]
  events[, V_China_Outbound := as.integer(visit_direction == "china_to_partner")]
  events[, V_Partner_Inbound := as.integer(visit_direction == "partner_to_china")]
  events[, V_ThirdParty := as.integer(visit_direction == "third_party_meeting" | 
                                       (visit_direction == "" & grepl("会晤|meeting|summit|APEC|G20|BRICS|ASEAN|UN", event_name, ignore.case = TRUE)))]
  
  # 生成 17 类事件指示（长表）
  events[, cat_id := event_category]
  ev_long <- events[, .(country_en, YearMonth, event_name, cat_id)]
  ev_long[, value := 1L]
  ev_wide <- dcast(ev_long, country_en + YearMonth ~ cat_id, value.var = "value", fun.aggregate = max, fill = 0L)
  setnames(ev_wide, old = names(ev_wide)[-(1:2)], new = paste0("Cat_", names(ev_wide)[-(1:2)]))
  
  # 国家名映射：事件库用 country_en，面板用 Country
  iso_map <- unique(panel[, .(ISO, Country)])
  setnames(iso_map, "Country", "country_en")
  events <- merge(events, iso_map, by = "country_en", all.x = TRUE)
  ev_wide <- merge(ev_wide, iso_map, by = "country_en", all.x = TRUE)
  
  # 按 ISO + YearMonth 聚合事件虚拟变量
  ev_agg <- events[, .(
    Event_Positive = max(Event_Positive, na.rm = TRUE),
    Event_Negative = max(Event_Negative, na.rm = TRUE),
    Event_Neutral = max(Event_Neutral, na.rm = TRUE),
    Event_Count = .N,
    V_RemoteTalk = max(V_RemoteTalk, na.rm = TRUE),
    V_China_Outbound = max(V_China_Outbound, na.rm = TRUE),
    V_Partner_Inbound = max(V_Partner_Inbound, na.rm = TRUE),
    V_ThirdParty = max(V_ThirdParty, na.rm = TRUE)
  ), by = .(ISO, YearMonth)]
  
  # 合并 17 类
  cat_cols <- setdiff(names(ev_wide), c("country_en", "YearMonth", "ISO"))
  ev_cat <- ev_wide[, lapply(.SD, max, na.rm = TRUE), by = .(ISO, YearMonth), .SDcols = cat_cols]
  
  # 合并到面板
  panel_ev <- merge(panel, ev_agg, by = c("ISO", "YearMonth"), all.x = TRUE)
  panel_ev <- merge(panel_ev, ev_cat, by = c("ISO", "YearMonth"), all.x = TRUE)
  
  # NA 填充为 0
  event_cols <- c("Event_Positive", "Event_Negative", "Event_Neutral", "Event_Count",
                  "V_RemoteTalk", "V_China_Outbound", "V_Partner_Inbound", "V_ThirdParty",
                  cat_cols)
  for (col in event_cols) {
    if (col %in% names(panel_ev)) {
      panel_ev[, (col) := ifelse(is.na(get(col)), 0L, get(col))]
    }
  }
  
  # 如果有分数，计算事件强度（Delta_Score）
  if (!is.null(scores)) {
    # 标准化分数
    scores[, zscore := {
      x <- Pol_Agg
      mu <- mean(x, na.rm = TRUE)
      sg <- sd(x, na.rm = TRUE)
      if (is.na(sg) || sg == 0) rep(NA_real_, .N) else (x - mu) / sg
    }, by = .(db, Country)]
    
    # 为每个事件计算 t-3 到 t-1 基线与 t+0 到 t+3 后期均值
    #（events 已在上方 merge 过 iso_map，此处直接使用 ISO 列）
    events[, Delta_Score_GDELT := NA_real_]
    events[, Delta_Score_ICEWS := NA_real_]
    events[, Delta_Score_Phoenix := NA_real_]
    events[, Delta_Score_Tsinghua := NA_real_]
    for (i in seq_len(nrow(events))) {
      events$Delta_Score_GDELT[i] <- calc_delta_score(events[i, ], scores, "GDELT")
      events$Delta_Score_ICEWS[i] <- calc_delta_score(events[i, ], scores, "ICEWS")
      events$Delta_Score_Phoenix[i] <- calc_delta_score(events[i, ], scores, "Phoenix")
      events$Delta_Score_Tsinghua[i] <- calc_delta_score(events[i, ], scores, "Tsinghua")
    }
    
    # 聚合到面板
    delta_agg <- events[, .(
      Delta_GDELT = mean(Delta_Score_GDELT, na.rm = TRUE),
      Delta_ICEWS = mean(Delta_Score_ICEWS, na.rm = TRUE),
      Delta_Phoenix = mean(Delta_Score_Phoenix, na.rm = TRUE),
      Delta_Tsinghua = mean(Delta_Score_Tsinghua, na.rm = TRUE)
    ), by = .(ISO, YearMonth)]
    panel_ev <- merge(panel_ev, delta_agg, by = c("ISO", "YearMonth"), all.x = TRUE)
  }
  
  setorder(panel_ev, ISO, YearMonth)
  return(panel_ev)
}

calc_delta_score <- function(ev_row, scores, db_name) {
  ctry <- ev_row$country_en
  edate <- ev_row$YearMonth
  db_sc <- scores[db == db_name & Country == ctry]
  if (nrow(db_sc) == 0) return(NA_real_)
  pre <- db_sc[YearMonth >= edate - 90 & YearMonth < edate, zscore]
  post <- db_sc[YearMonth >= edate & YearMonth <= edate + 90, zscore]
  if (length(pre) == 0 || length(post) == 0 || all(is.na(pre)) || all(is.na(post))) return(NA_real_)
  return(mean(post, na.rm = TRUE) - mean(pre, na.rm = TRUE))
}

# ---- 生成滞后变量 ----
make_event_lags <- function(panel_ev, vars, horizons = c(0, 1, 3, 6, 12)) {
  setorder(panel_ev, ISO, YearMonth)
  for (v in vars) {
    for (h in horizons) {
      if (h == 0) next
      panel_ev[, (paste0(v, "_L", h)) := shift(get(v), n = h, type = "lag"), by = ISO]
    }
  }
  return(panel_ev)
}

# ---- 标准控制变量 ----
CONTROLS <- c("ln_GDP_product", "ln_ER", "FTA_Dummy")
DBS <- c("GDELT", "ICEWS", "Phoenix", "Tsinghua")
TRADE_VARS <- c("Trade_Total", "Trade_Exports", "Trade_Imports")
VISIT_VARS <- c("V_RemoteTalk", "V_China_Outbound", "V_Partner_Inbound", "V_ThirdParty")
