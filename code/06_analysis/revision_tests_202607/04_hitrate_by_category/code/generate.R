# 04_合作冲突分类命中率全表

suppressMessages({library(dplyr); library(tidyr); library(readr); library(ggplot2)})

SRC <- "../../../3.2 双边关系分析基于月度政治分数/全新事件研究法/09_四库事件命中率测试/code/results/hit_data_full.csv"
dir.create("../results", showWarnings=FALSE, recursive=TRUE)
dir.create("../figures", showWarnings=FALSE, recursive=TRUE)

hit <- read_csv(SRC, show_col_types=FALSE) %>%
  filter(window %in% c("W_strict","W_1m","W_2m")) %>%
  mutate(window=factor(window, levels=c("W_strict","W_1m","W_2m")))

# ---- CAMEO quadclass mapping (documented in README) ----
quad_map <- c(
  "Strategic partnership upgrade"            = "Verbal cooperation",
  "Cultural / people-to-people cooperation"  = "Verbal cooperation",
  "High-level visit"                         = "Verbal cooperation",
  "Multilateral / third-party meeting"       = "Verbal cooperation",
  "Economic win-win cooperation"             = "Material cooperation",
  "Military / security cooperation"          = "Material cooperation",
  "Pandemic / crisis aid"                    = "Material cooperation",
  "Diplomatic protest / friction"            = "Verbal conflict",
  "Negative strategic positioning"           = "Verbal conflict",
  "Policy shift / domestic politics"         = "Verbal conflict",
  "Economic sanction / tariff barrier"       = "Material conflict",
  "Tech control / export restriction"        = "Material conflict",
  "Detention / judicial dispute"             = "Material conflict",
  "Sovereignty dispute"                      = "Material conflict",
  "Security threat"                          = "Material conflict",
  "Pandemic / disaster shock"                = NA_character_  # exogenous shock, not a CAMEO behavior
)
hit <- hit %>%
  mutate(quadclass = quad_map[event_category],
         coop_conf = ifelse(event_sign==1, "Cooperation", "Conflict/Shock"))

# ---- 1. Full matrix: event_category x db x window ----
wilson <- function(k, n, z=1.96) {
  p <- k/n; den <- 1+z^2/n
  ctr <- (p + z^2/(2*n))/den; half <- z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den
  c(lo=ctr-half, hi=ctr+half)
}

# coop_conf of a category = majority sign of its events
cat_sign <- hit %>% group_by(event_category) %>% summarise(cs=mean(event_sign>0)>0.5, .groups="drop")
by_cat <- hit %>%
  group_by(event_category, db, window) %>%
  summarise(n_events=n_distinct(event_name), n_hit=sum(hit, na.rm=TRUE),
            hit_rate=mean(hit, na.rm=TRUE), .groups="drop") %>%
  mutate(quadclass=quad_map[event_category]) %>%
  left_join(cat_sign %>% mutate(coop_conf=ifelse(cs,"Cooperation","Conflict/Shock")) %>% select(-cs),
            by="event_category") %>%
  arrange(coop_conf, quadclass, event_category, db, window)
write_csv(by_cat, "../results/hitrate_by_category_full.csv")

# ---- 2. Aggregations: 4 CAMEO quadrants + cooperation vs conflict ----
agg_quad <- hit %>% filter(!is.na(quadclass)) %>%
  group_by(group_type="CAMEO quadrant", group=quadclass, db, window) %>%
  summarise(n_events=n_distinct(event_name), n_hit=sum(hit,na.rm=TRUE),
            hit_rate=mean(hit,na.rm=TRUE), .groups="drop")
agg_cc <- hit %>%
  group_by(group_type="Cooperation vs Conflict", group=coop_conf, db, window) %>%
  summarise(n_events=n_distinct(event_name), n_hit=sum(hit,na.rm=TRUE),
            hit_rate=mean(hit,na.rm=TRUE), .groups="drop")
agg_all <- bind_rows(agg_quad, agg_cc) %>%
  rowwise() %>%
  mutate(ci_lo=wilson(n_hit,n_events)[1], ci_hi=wilson(n_hit,n_events)[2]) %>%
  ungroup() %>%
  arrange(group_type, group, db, window)
write_csv(agg_all, "../results/hitrate_cooperation_vs_conflict.csv")

# ---- 3. Forest plot: Cooperation vs Conflict, 4 DBs, 3 windows ----
pd <- agg_all %>% filter(group_type=="Cooperation vs Conflict") %>%
  rename(coop_conf=group) %>%
  mutate(db=factor(db, levels=rev(c("GDELT","ICEWS","Phoenix","Tsinghua"))),
         label=sprintf("%.1f%% (%d/%d)", 100*hit_rate, n_hit, n_events))
vl <- expand.grid(coop_conf=unique(pd$coop_conf), window=levels(pd$window)) %>%
  mutate(window=factor(window, levels=levels(pd$window)))
p <- ggplot(pd, aes(x=hit_rate, y=db, color=db)) +
  geom_vline(data=vl, aes(xintercept=0.5), linetype="dashed", color="grey60", inherit.aes=FALSE) +
  geom_errorbar(aes(xmin=ci_lo, xmax=ci_hi), height=0.25, linewidth=0.7, orientation="y") +
  geom_point(size=2.8) +
  geom_text(aes(label=label), vjust=-1.1, size=3.0, show.legend=FALSE) +
  facet_grid(coop_conf ~ window) +
  scale_x_continuous(labels=scales::percent_format(accuracy=1), limits=c(0.25,0.9)) +
  scale_color_manual(values=c(GDELT="#2166ac", ICEWS="#b2182b",
                              Phoenix="#1b7837", Tsinghua="#e08214")) +
  labs(title="Event hit rate by database: cooperation vs conflict events",
       subtitle="Hit = index change direction matches event sign. Error bars: 95% Wilson CI. n shown as hits/events.",
       x="Hit rate", y=NULL, color="Database") +
  theme_bw(base_size=11) +
  theme(legend.position="none", strip.background=element_rect(fill="grey92"),
        plot.title=element_text(face="bold"))
ggsave("../figures/hitrate_forest.png", p, width=10, height=6, dpi=320)

cat("=== Cooperation vs Conflict (hit rate) ===\n")
print(as.data.frame(agg_cc %>% mutate(hit_rate=round(hit_rate,3)) %>%
  pivot_wider(names_from=window, values_from=c(n_events,hit_rate)) %>%
  arrange(group, db)), row.names=FALSE)
cat("\n=== CAMEO quadrants (W_strict) ===\n")
print(as.data.frame(agg_quad %>% filter(window=="W_strict") %>%
  mutate(hit_rate=round(hit_rate,3)) %>% arrange(group, db)), row.names=FALSE)
cat("\nDone.\n")
