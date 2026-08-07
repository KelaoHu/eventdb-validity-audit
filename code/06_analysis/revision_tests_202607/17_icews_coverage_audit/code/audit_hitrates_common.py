# audit_hitrates_common.py — 公共窗口（事件<=2019-03）四库命中率对照

import csv, io
BASE = r"C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\全新事件研究法"
ev_date = {}
with io.open(BASE + "\\data\\events_712.csv", encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        ev_date[row["event_name"]] = row["event_date"]
hits = []
with io.open(BASE + "\\09_四库事件命中率测试\\code\\results\\hit_data_full.csv", encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        row["hit"] = row["hit"] == "TRUE"
        row["date"] = ev_date.get(row["event_name"])
        hits.append(row)
print("公共窗口对照（事件<=2019-03，四库全部为真实数据段）")
for w in ["W_strict", "W_1m", "W_2m"]:
    print(f"-- {w}")
    for db in ["GDELT", "ICEWS", "Phoenix", "Tsinghua"]:
        sub = [h for h in hits if h["db"] == db and h["window"] == w and h["date"] and h["date"] <= "2019-03"]
        if sub:
            nh = sum(h["hit"] for h in sub)
            print(f"  {db:9s} {nh}/{len(sub)} = {nh/len(sub)*100:.1f}%")
