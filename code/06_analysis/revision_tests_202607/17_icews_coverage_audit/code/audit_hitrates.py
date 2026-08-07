# audit_hitrates.py — ICEWS/Phoenix 填充段对命中率影响的定量核算

import csv, io, collections

BASE = r"C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\全新事件研究法"
OUT  = r"C:\Users\胡克劳\Desktop\Python代码存放\tmp\audit_hitrates_out.txt"

# 事件日期表
ev_date = {}
with io.open(f"{BASE}\\data\\events_712.csv", encoding="utf-8-sig") as f:
    r = csv.DictReader(f)
    for row in r:
        ev_date[row["event_name"]] = row["event_date"]

hits = []
with io.open(f"{BASE}\\09_四库事件命中率测试\\code\\results\\hit_data_full.csv", encoding="utf-8-sig") as f:
    r = csv.DictReader(f)
    for row in r:
        row["hit"] = row["hit"] == "TRUE"
        row["date"] = ev_date.get(row["event_name"], None)
        hits.append(row)

out = io.open(OUT, "w", encoding="utf-8")
real_end = {"ICEWS": "2023-04", "Phoenix": "2019-03", "GDELT": "2025-12", "Tsinghua": "2025-08"}

for w in ["W_strict", "W_1m", "W_2m"]:
    out.write(f"\n===== 窗口 {w} =====\n")
    for db in ["GDELT", "ICEWS", "Phoenix", "Tsinghua"]:
        sub = [h for h in hits if h["db"] == db and h["window"] == w]
        if not sub: continue
        n_all, hit_all = len(sub), sum(h["hit"] for h in sub)
        # 截断：事件月 <= 真实截止月（窗口后延跨越问题：W_strict 无后延；W_1m 后延1月；W_2m 后延2月——此处先按事件月粗截，脚本2再做精确）
        cut = real_end[db]
        sub_t = [h for h in sub if h["date"] and h["date"] <= cut]
        n_t, hit_t = len(sub_t), sum(h["hit"] for h in sub_t)
        # 填充段事件
        sub_f = [h for h in sub if h["date"] and h["date"] > cut]
        n_f, hit_f = len(sub_f), sum(h["hit"] for h in sub_f)
        out.write(f"{db:9s} 全期: {hit_all}/{n_all} = {hit_all/n_all*100:.1f}% | "
                  f"截断(事件<={cut}): {hit_t}/{n_t} = {(hit_t/n_t*100 if n_t else 0):.1f}% | "
                  f"填充段事件(>{cut}): {hit_f}/{n_f} = {(hit_f/n_f*100 if n_f else 0):.1f}%\n")
out.close()
print(io.open(OUT, encoding="utf-8").read())
