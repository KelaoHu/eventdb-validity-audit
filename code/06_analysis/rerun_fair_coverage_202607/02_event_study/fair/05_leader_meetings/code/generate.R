# 05_领导人会晤效应与双边关系 (4-category version)

library(tidyverse)
library(lubridate)

SD <- "C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法/data_fair"
DIR_OUT <- "results"
dir.create(DIR_OUT, showWarnings = FALSE, recursive = TRUE)

# -----------------------------
# 读取事件与分数
# -----------------------------
events <- read_csv(
  file.path(SD, "events_712.csv"),
  show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
) %>%
  mutate(event_date_ym = ymd(paste0(event_date, "-01")))

visits <- events %>% filter(event_type_original == "leader_visit")
cat(sprintf("Module 5: %d leader visit events loaded\n", nrow(visits)))

sc <- read_csv(
  file.path(SD, "scores_v3_GDELT_ICEWS_2025.csv"),
  show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
)

# -----------------------------
# 4 分类函数
# -----------------------------
classify_visit_4 <- function(df) {
  df %>%
    mutate(
      category_4 = case_when(
        event_category_en == "Remote talk / virtual meeting" ~ "Remote talk",
        visit_direction == "china_to_partner" ~ "Chinese outbound visit",
        visit_direction == "partner_to_china" ~ "Partner inbound visit",
        visit_direction == "third_party_meeting" ~ "Third-party meeting",
        TRUE ~ NA_character_
      )
    ) %>%
    mutate(category_4 = case_when(
      # 对少量 visit_direction 缺失/不适用但类别不是远程的事件进行推断
      is.na(category_4) & event_category_en != "Remote talk / virtual meeting" &
        str_detect(tolower(event_name), "to china|visits china|in china") ~ "Partner inbound visit",
      is.na(category_4) & event_category_en != "Remote talk / virtual meeting" &
        str_detect(tolower(event_name), "state visit to|official visit to|visit to ") ~ "Chinese outbound visit",
      TRUE ~ category_4
    ))
}

visits <- visits %>% classify_visit_4()

unclassified <- visits %>% filter(is.na(category_4))
if (nrow(unclassified) > 0) {
  cat("[WARNING] 未分类事件（将被剔除）：\n")
  print(unclassified %>% select(country_en, event_date, event_name, visit_direction, event_category_en))
} else {
  cat("[OK] 所有领导人会晤事件均已归入 4 类\n")
}

visits <- visits %>% filter(!is.na(category_4))
cat(sprintf("用于分析的事件数：%d\n", nrow(visits)))

# -----------------------------
# 计算冲击
# -----------------------------
post_months <- c(0, 1, 2, 3, 6, 12)

res <- list()
for (db in unique(sc$db)) {
  db_sc <- sc %>% filter(db == !!db)
  for (cty in unique(visits$country_en)) {
    cty_ev <- visits %>% filter(country_en == cty)
    cty_sc <- db_sc %>% filter(country == cty)
    if (nrow(cty_ev) == 0 || nrow(cty_sc) == 0) next

    for (i in seq_len(nrow(cty_ev))) {
      ed <- cty_ev$event_date_ym[i]
      pre <- cty_sc %>% filter(month >= ed %m-% months(3), month < ed)
      bl <- mean(pre$value, na.rm = TRUE)
      if (is.na(bl)) next

      for (pm in post_months) {
        post <- cty_sc %>% filter(month == ed %m+% months(pm))
        if (nrow(post) > 0 && !is.na(post$value[1])) {
          res[[length(res) + 1]] <- tibble(
            db = db,
            country = cty,
            event_date = ed,
            event_name = cty_ev$event_name[i],
            category_4 = cty_ev$category_4[i],
            post_month = pm,
            baseline = bl,
            shock = post$value[1] - bl
          )
        }
      }
    }
  }
}

out <- bind_rows(res)
write_csv(out, file.path(DIR_OUT, "leader_meeting_effects.csv"))
cat(sprintf("[DONE] leader_meeting_effects.csv: %d observations\n", nrow(out)))

# -----------------------------
# 按 4 类汇总（post_month=0）
# -----------------------------
direction_summary <- out %>%
  filter(post_month == 0) %>%
  group_by(db, category_4) %>%
  summarise(
    mean = mean(shock, na.rm = TRUE),
    sd = sd(shock, na.rm = TRUE),
    n = n(),
    se = sd / sqrt(n),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

write_csv(direction_summary, file.path(DIR_OUT, "direction_summary.csv"))
cat("[DONE] direction_summary.csv\n")
print(direction_summary)

# -----------------------------
# 保存 4 分类样本量清单
# -----------------------------
counts <- visits %>%
  count(category_4, name = "n_events")
write_csv(counts, file.path(DIR_OUT, "category4_event_counts.csv"))
cat("[DONE] category4_event_counts.csv\n")
print(counts)
