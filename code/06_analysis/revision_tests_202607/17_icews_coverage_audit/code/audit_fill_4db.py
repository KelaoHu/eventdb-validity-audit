# audit_fill_4db.py — 四库分数文件“真实覆盖 vs 填充”统一审计

import csv, io, collections

BASE = r"C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\全新事件研究法\data"
OUT  = r"C:\Users\胡克劳\Desktop\Python代码存放\tmp\audit_fill_4db_out.txt"

def audit_long(fname, col_country, col_month, col_value, col_type=None, type_val=None, encoding="utf-8-sig"):
    series = collections.defaultdict(list)   # key -> [(month, value or None)]
    with io.open(f"{BASE}\\{fname}", encoding=encoding) as f:
        r = csv.reader(f)
        hdr = next(r)
        for row in r:
            if len(row) <= max(col_country, col_month, col_value):
                continue
            if col_type is not None and row[col_type] != type_val:
                continue
            c, m, v = row[col_country], row[col_month], row[col_value]
            val = None if v in ("", "NA", "NaN") else float(v)
            key = c if col_type is None else f"{c}|{row[col_type]}"
            series[key].append((m, val))
    stats = []
    for key, arr in series.items():
        arr.sort()
        months = [m for m, _ in arr]
        na = sum(1 for _, v in arr if v is None)
        zero = sum(1 for _, v in arr if v is not None and v == 0.0)
        # last month where value differs from previous non-NA value
        last_change = months[0]
        prev = None
        for m, v in arr:
            if v is None:
                continue
            if prev is not None and abs(v - prev) > 1e-12:
                last_change = m
            prev = v
        # trailing constant months (from last_change to end, non-NA)
        tail = sum(1 for m, v in arr if m > last_change and v is not None)
        stats.append(dict(key=key, first=months[0], last=months[-1], n=len(arr),
                          na=na, zero=zero, last_change=last_change, tail_const=tail))
    return stats

def summarize(name, stats, out):
    out.write(f"\n===== {name} =====\n")
    lc = collections.Counter(s["last_change"] for s in stats)
    out.write(f"series数: {len(stats)}; 月份范围: {min(s['first'] for s in stats)} ~ {max(s['last'] for s in stats)}\n")
    out.write(f"NA总数: {sum(s['na'] for s in stats)}; 零值总数: {sum(s['zero'] for s in stats)}\n")
    out.write("最后一次数值变化月分布:\n")
    for m, c in sorted(lc.items()):
        out.write(f"  {m}: {c} 条序列\n")
    out.write("尾部恒定月数分布:\n")
    tc = collections.Counter(s["tail_const"] for s in stats)
    for t, c in sorted(tc.items()):
        out.write(f"  {t}个月: {c} 条序列\n")

out = io.open(OUT, "w", encoding="utf-8")

# 三个 Index_Type 都审（Aggregated 是正文主用）
for f, label in [("gdelt_scores.csv", "GDELT"), ("icews_scores.csv", "ICEWS"), ("phoenix_scores.csv", "Phoenix")]:
    stats = audit_long(f, 0, 2, 3, col_type=1, type_val="Aggregated")
    summarize(f"{label} (Aggregated)", stats, out)

stats = audit_long("tsinghua_scores.csv", 0, 1, 2)
summarize("Tsinghua", stats, out)

# 事件研究用的整合文件
for f, label in [("scores_v1_4DB_2019.csv", "v1_4DB_2019"), ("scores_v2_3DB_2025.csv", "v2_3DB_2025"), ("scores_v3_GDELT_ICEWS_2025.csv", "v3_GDELT_ICEWS_2025")]:
    try:
        # country, month, value, zscore, db
        with io.open(f"{BASE}\\{f}", encoding="utf-8-sig") as fh:
            hdr = next(csv.reader(fh))
        dbs = set()
        with io.open(f"{BASE}\\{f}", encoding="utf-8-sig") as fh:
            r = csv.reader(fh); next(r)
            for row in r: dbs.add(row[4])
        for db in sorted(dbs):
            series = collections.defaultdict(list)
            with io.open(f"{BASE}\\{f}", encoding="utf-8-sig") as fh:
                r = csv.reader(fh); next(r)
                for row in r:
                    if row[4] != db: continue
                    v = None if row[2] in ("", "NA") else float(row[2])
                    series[row[0]].append((row[1][:7], v))
            stats = []
            for c, arr in series.items():
                arr.sort()
                months = [m for m, _ in arr]
                na = sum(1 for _, v in arr if v is None)
                last_change = months[0]; prev = None
                for m, v in arr:
                    if v is None: continue
                    if prev is not None and abs(v - prev) > 1e-12: last_change = m
                    prev = v
                tail = sum(1 for m, v in arr if m > last_change and v is not None)
                stats.append(dict(key=c, first=months[0], last=months[-1], n=len(arr), na=na, zero=0, last_change=last_change, tail_const=tail))
            summarize(f"{label} / {db}", stats, out)
    except FileNotFoundError:
        out.write(f"\n===== {label} ===== 文件不存在\n")

out.close()
print("done ->", OUT)
