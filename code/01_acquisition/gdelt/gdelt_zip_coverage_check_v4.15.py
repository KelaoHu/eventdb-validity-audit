import re
from pathlib import Path
import pandas as pd

ZIP_DIR = r"C:\Users\胡克劳\Desktop\GDELT\ZIP"

START_DATE = pd.Timestamp("2002-01-01")
END_DATE = pd.Timestamp("2025-12-31")

def infer_package_info(zip_name):
    base = Path(zip_name).name

    m8 = re.search(r"(?<!\d)(\d{8})(?!\d)", base)
    if m8:
        d = pd.to_datetime(m8.group(1), format="%Y%m%d", errors="coerce")
        return d, d, "daily"

    m6 = re.search(r"(?<!\d)(\d{6})(?!\d)", base)
    if m6:
        d = pd.to_datetime(m6.group(1), format="%Y%m", errors="coerce")
        return d, d + pd.offsets.MonthEnd(0), "monthly"

    m4 = re.search(r"(?<!\d)(\d{4})(?!\d)", base)
    if m4:
        d = pd.to_datetime(m4.group(1), format="%Y", errors="coerce")
        return d, pd.Timestamp(f"{d.year}-12-31"), "yearly"

    return None, None, "unknown"

def overlap(a_start, a_end, b_start, b_end):
    return not (a_end < b_start or a_start > b_end)

# 扫描
zip_files = list(Path(ZIP_DIR).rglob("*.zip"))

excluded = []

for zp in zip_files:
    start, end, pkg_type = infer_package_info(zp.name)

    if start is None:
        excluded.append((zp.name, "无法识别日期"))
        continue

    if not overlap(start, end, START_DATE, END_DATE):
        excluded.append((zp.name, f"不在时间范围 ({start.date()} ~ {end.date()})"))

# 输出结果
print(f"\n被排除的文件数量: {len(excluded)}\n")

for name, reason in excluded:
    print(f"{name}  -->  {reason}")
