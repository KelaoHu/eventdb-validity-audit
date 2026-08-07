suppressMessages(library(tidyverse)); suppressMessages(library(lubridate))
setwd("C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/全新事件研究法")
sc <- read_csv("data/scores_v3_GDELT_ICEWS_2025.csv", show_col_types = FALSE)
db_sc <- sc %>% filter(db == "GDELT")
nd <- ymd("2011-10-01")
pre <- db_sc %>% filter(month >= nd %m-% months(3), month < nd) %>%
  group_by(country) %>% summarise(bl = mean(value, na.rm = T), .groups = "drop")
third <- db_sc %>% filter(month >= nd, month <= nd %m+% months(6)) %>%
  left_join(pre, by = "country") %>% filter(!is.na(bl), country != "United States") %>%
  group_by(country) %>% summarise(avg_shock = mean(value - bl, na.rm = T), .groups = "drop")
cat("replica 2011-10 mean:", mean(third$avg_shock), "\n")
m8 <- read_csv("08_中美竞争第三方效应与体系结构变迁/results/third_party_effects.csv", show_col_types = FALSE)
cat("M8 csv 2011-10 mean:", mean((m8 %>% filter(db == "GDELT", node_date == "2011-10-01"))$avg_shock), "\n")
cmp <- full_join(third, m8 %>% filter(db == "GDELT", node_date == "2011-10-01") %>% select(country, m8 = avg_shock), by = "country") %>%
  mutate(diff = avg_shock - m8) %>% arrange(desc(abs(diff)))
print(head(cmp, 8))
