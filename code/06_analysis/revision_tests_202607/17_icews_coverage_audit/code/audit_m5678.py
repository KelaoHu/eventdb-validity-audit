# audit_m5678.py — M5/M7/M8 逐事件层面 ICEWS 填充段污染量化

import csv, io, collections, statistics

BASE = r"C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\全新事件研究法"
CUT = "2023-04"

def col_stats(rows, val_idx, name):
    pre = [r[val_idx] for r in rows if r[2] <= CUT]
    post = [r[val_idx] for r in rows if r[2] > CUT]
    print(f"  {name}: ≤2023-04 n={len(pre)} mean={statistics.mean(pre):+.4f}" if pre else f"  {name}: ≤2023-04 n=0", end="")
    print(f" | >2023-04 n={len(post)} mean={statistics.mean(post):+.4f}" if post else " | >2023-04 n=0")

# ---- M5 会晤效应：h=0 shock ----
print("== M5 领导人会晤（ICEWS, h=0 逐事件 shock）==")
rows = []
with io.open(BASE + r"\05_领导人会晤效应与双边关系\code\results\leader_meeting_effects.csv", encoding="utf-8-sig") as f:
    for r in csv.DictReader(f):
        if r["db"] == "ICEWS" and r["post_month"] == "0":
            rows.append((r["db"], r["country"], r["event_date"][:7], float(r["shock"])))
col_stats(rows, 3, "全部事件")
# 按四方向
by_cat = collections.defaultdict(list)
for r in rows:
    by_cat[r[1] and r[3]].append(r)  # placeholder
cats = collections.defaultdict(list)
with io.open(BASE + r"\05_领导人会晤效应与双边关系\code\results\leader_meeting_effects.csv", encoding="utf-8-sig") as f:
    for r in csv.DictReader(f):
        if r["db"] == "ICEWS" and r["post_month"] == "0":
            cats[r["category_4"]].append((r["event_date"][:7], float(r["shock"])))
for c, arr in cats.items():
    pre = [s for d, s in arr if d <= CUT]; post = [s for d, s in arr if d > CUT]
    pm = f"{statistics.mean(pre):+.4f}(n={len(pre)})" if pre else "NA"
    qm = f"{statistics.mean(post):+.4f}(n={len(post)})" if post else "NA"
    print(f"  {c:28s} ≤2023-04: {pm:>16s} | >2023-04: {qm}")

# ---- M8 第三方溢出：节点日期 ----
print("\n== M8 中美竞争第三方效应：15 节点中 >2023-04 的数量 ==")
with io.open(BASE + r"\08_中美竞争第三方效应与体系结构变迁\检验结果CSV\third_country_event_metrics.csv", encoding="utf-8-sig") as f:
    rows8 = list(csv.DictReader(f))
print("  列:", list(rows8[0].keys())[:12])
dates8 = sorted(set(r.get("event_date", r.get("node_date", ""))[:7] for r in rows8))
print("  节点:", dates8)
print("  >2023-04 节点数:", sum(1 for d in dates8 if d > CUT))
