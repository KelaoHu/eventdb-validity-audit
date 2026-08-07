import csv
import os
import re
import sys
import zipfile
import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pandas as pd


# ============================================================
# 1) 基本配置
# ============================================================

START_DATE = pd.Timestamp("2002-01-01")
END_DATE = pd.Timestamp("2025-12-31")

# 你的 GDELT 本地 ZIP 目录
ZIP_DIR = r"C:\Users\胡克劳\Desktop\GDELT\ZIP"

# 输出目录
SAVE_DIR = r"C:\Users\胡克劳\Desktop\GDELT\中国_图中25国_双边关系检索结果"

# 并行进程数
MAX_WORKERS = 4

# 是否把输出 CSV 追加写入（True）还是先全部汇总到内存后一次性写出（False）
# 这里采用逐文件追加，减少内存压力。
APPEND_WRITE = True

# 每个子进程读取 CSV 的块大小（保留作为后续升级接口）
# 当前版本按整文件读取，代码更直观，日志也更清晰。
CHUNK_SIZE = 200_000

os.makedirs(SAVE_DIR, exist_ok=True)

RUN_TIME = datetime.now().strftime("%Y%m%d_%H%M%S")
LOG_TXT = os.path.join(SAVE_DIR, f"检索过程记录_{RUN_TIME}.txt")
SUMMARY_TXT = os.path.join(SAVE_DIR, f"检索汇总_{RUN_TIME}.txt")
FILE_REPORT_CSV = os.path.join(SAVE_DIR, f"逐文件检索明细_{RUN_TIME}.csv")
FINAL_CSV = os.path.join(SAVE_DIR, f"中美及图中25国严格双边事件_{RUN_TIME}.csv")

# ============================================================
# 2) 目标国家：图中左侧 25 个对象国
#    严格 dyad：只认 Actor1CountryCode / Actor2CountryCode
# ============================================================

TARGET_COUNTRY_CODES: Dict[str, str] = {
    "Japan": "JPN",
    "United States": "USA",
    "South Korea": "KOR",
    "Germany": "DEU",
    "Malaysia": "MYS",
    "Singapore": "SGP",
    "Russia": "RUS",
    "United Kingdom": "GBR",
    "Netherlands": "NLD",
    "Australia": "AUS",
    "Italy": "ITA",
    "Thailand": "THA",
    "France": "FRA",
    "Indonesia": "IDN",
    "Canada": "CAN",
    "Philippines": "PHL",
    "Saudi Arabia": "SAU",
    "India": "IND",
    "Belgium": "BEL",
    "Brazil": "BRA",
    "Mexico": "MEX",
    "United Arab Emirates": "ARE",
    "Iran": "IRN",
    "Spain": "ESP",
    "Vietnam": "VNM",
}

CHINA_CODE = "CHN"
TARGET_CODES_SET = set(TARGET_COUNTRY_CODES.values())
DYAD_CODES_SET = TARGET_CODES_SET | {CHINA_CODE}

# ============================================================
# 3) GDELT 1.0 列名
#    1979-2013-03-31：57 列
#    2013-04-01 以后：58 列（多 SOURCEURL）
# ============================================================

GDELT_COLUMNS_57 = [
    "GlobalEventID",
    "SQLDATE",
    "MonthYear",
    "Year",
    "FractionDate",
    "Actor1Code",
    "Actor1Name",
    "Actor1CountryCode",
    "Actor1KnownGroupCode",
    "Actor1EthnicCode",
    "Actor1Religion1Code",
    "Actor1Religion2Code",
    "Actor1Type1Code",
    "Actor1Type2Code",
    "Actor1Type3Code",
    "Actor2Code",
    "Actor2Name",
    "Actor2CountryCode",
    "Actor2KnownGroupCode",
    "Actor2EthnicCode",
    "Actor2Religion1Code",
    "Actor2Religion2Code",
    "Actor2Type1Code",
    "Actor2Type2Code",
    "Actor2Type3Code",
    "IsRootEvent",
    "EventCode",
    "EventBaseCode",
    "EventRootCode",
    "QuadClass",
    "GoldsteinScale",
    "NumMentions",
    "NumSources",
    "NumArticles",
    "AvgTone",
    "Actor1Geo_Type",
    "Actor1Geo_FullName",
    "Actor1Geo_CountryCode",
    "Actor1Geo_ADM1Code",
    "Actor1Geo_Lat",
    "Actor1Geo_Long",
    "Actor1Geo_FeatureID",
    "Actor2Geo_Type",
    "Actor2Geo_FullName",
    "Actor2Geo_CountryCode",
    "Actor2Geo_ADM1Code",
    "Actor2Geo_Lat",
    "Actor2Geo_Long",
    "Actor2Geo_FeatureID",
    "ActionGeo_Type",
    "ActionGeo_FullName",
    "ActionGeo_CountryCode",
    "ActionGeo_ADM1Code",
    "ActionGeo_Lat",
    "ActionGeo_Long",
    "ActionGeo_FeatureID",
    "DATEADDED",
]

GDELT_COLUMNS_58 = GDELT_COLUMNS_57 + ["SOURCEURL"]

# 输出列，保证最终 CSV 统一
KEEP_COLS = [
    "GlobalEventID", "SQLDATE", "EventDate", "Year", "MonthYear", "FractionDate",
    "Actor1Code", "Actor1Name", "Actor1CountryCode",
    "Actor2Code", "Actor2Name", "Actor2CountryCode",
    "EventCode", "EventBaseCode", "EventRootCode", "QuadClass",
    "GoldsteinScale", "NumMentions", "NumSources", "NumArticles", "AvgTone",
    "DATEADDED", "SOURCEURL", "SourceZip", "PackageType", "PackageStart", "PackageEnd", "Direction"
]

# ============================================================
# 4) 日志系统
# ============================================================

class DualLogger:
    def __init__(self, log_file_path: str):
        self.terminal = sys.stdout
        self.log = open(log_file_path, "a", encoding="utf-8")

    def write(self, message: str):
        self.terminal.write(message)
        self.log.write(message)
        self.flush()

    def flush(self):
        self.terminal.flush()
        self.log.flush()


# ============================================================
# 5) 包类型识别：年包 / 月包 / 日包
# ============================================================

@dataclass
class PackageInfo:
    package_type: str   # yearly / monthly / daily / unknown
    start: pd.Timestamp
    end: pd.Timestamp
    token: str          # 识别出的年月日字符串


def _month_end(ts: pd.Timestamp) -> pd.Timestamp:
    return (ts + pd.offsets.MonthEnd(0)).normalize()


def infer_package_info(zip_name: str) -> PackageInfo:
    """
    根据文件名推断包类型和覆盖日期范围。
    规则：
    - 8 位数字：日包
    - 6 位数字：月包
    - 4 位数字：年包
    """
    base = Path(zip_name).name

    m8 = re.search(r"(?<!\d)(\d{8})(?!\d)", base)
    if m8:
        d = pd.to_datetime(m8.group(1), format="%Y%m%d", errors="coerce")
        if pd.notna(d):
            d = pd.Timestamp(d).normalize()
            return PackageInfo("daily", d, d, m8.group(1))

    m6 = re.search(r"(?<!\d)(\d{6})(?!\d)", base)
    if m6:
        d = pd.to_datetime(m6.group(1), format="%Y%m", errors="coerce")
        if pd.notna(d):
            d = pd.Timestamp(d).normalize()
            return PackageInfo("monthly", d, _month_end(d), m6.group(1))

    m4 = re.search(r"(?<!\d)(\d{4})(?!\d)", base)
    if m4:
        d = pd.to_datetime(m4.group(1), format="%Y", errors="coerce")
        if pd.notna(d):
            d = pd.Timestamp(d).normalize()
            return PackageInfo("yearly", d, pd.Timestamp(f"{d.year}-12-31"), m4.group(1))

    return PackageInfo("unknown", pd.NaT, pd.NaT, "")


def overlap(a_start: pd.Timestamp, a_end: pd.Timestamp,
            b_start: pd.Timestamp, b_end: pd.Timestamp) -> bool:
    return not (a_end < b_start or a_start > b_end)


# ============================================================
# 6) ZIP 内部读取与列名适配
# ============================================================

def choose_zip_member(zf: zipfile.ZipFile) -> Optional[str]:
    members = [n for n in zf.namelist() if not n.endswith("/")]
    if not members:
        return None
    preferred = [n for n in members if n.lower().endswith(".csv") or ".csv" in n.lower()]
    return preferred[0] if preferred else members[0]


def count_fields_in_first_data_row(zip_path: Path) -> Tuple[int, Optional[str]]:
    """
    读取 ZIP 内第一个非空行，统计 tab 字段数。
    返回：(字段数, 成员文件名)
    """
    with zipfile.ZipFile(zip_path, "r") as zf:
        member = choose_zip_member(zf)
        if member is None:
            return 0, None

        with zf.open(member) as raw:
            for line in raw:
                if line.strip():
                    text = line.decode("utf-8", errors="replace").rstrip("\n\r")
                    return len(text.split("\t")), member
    return 0, member


def read_gdelt_zip(zip_path: Path) -> Tuple[pd.DataFrame, int, str]:
    """
    读取一个 ZIP，自动识别 57/58 列 schema。
    返回：(df, 实际字段数, 成员文件名)
    """
    field_count, member = count_fields_in_first_data_row(zip_path)

    if field_count == 58:
        names = GDELT_COLUMNS_58
    elif field_count == 57:
        names = GDELT_COLUMNS_57
    else:
        raise ValueError(
            f"无法识别字段数：{field_count}。"
            f"预期为 57（1979-2013-03）或 58（2013-04 以后）。"
        )

    with zipfile.ZipFile(zip_path, "r") as zf:
        if member is None:
            return pd.DataFrame(columns=names), field_count, member

        with zf.open(member) as raw:
            df = pd.read_csv(
                raw,
                sep="\t",
                header=None,
                names=names,
                dtype=str,
                low_memory=False,
                encoding="utf-8",
                on_bad_lines="skip",
            )

    # 统一补齐 SOURCEURL，保证后续输出列一致
    if "SOURCEURL" not in df.columns:
        df["SOURCEURL"] = pd.NA

    return df, field_count, member or ""


# ============================================================
# 7) 日期与严格 dyad 过滤
# ============================================================

def to_series_str(s: pd.Series) -> pd.Series:
    return s.fillna("").astype(str).str.upper().str.strip()


def parse_event_date(df: pd.DataFrame) -> pd.Series:
    """
    优先使用 SQLDATE。
    如果极少数情况 SQLDATE 异常，再用 MonthYear 兜底。
    """
    sql = pd.to_numeric(
        df.get("SQLDATE", pd.Series(index=df.index, dtype="float64")),
        errors="coerce"
    )
    event_date = pd.to_datetime(
        sql.astype("Int64").astype(str).str.zfill(8),
        format="%Y%m%d",
        errors="coerce"
    )

    if "MonthYear" in df.columns:
        missing = event_date.isna()
        if missing.any():
            my = pd.to_numeric(df.loc[missing, "MonthYear"], errors="coerce")
            fallback = pd.to_datetime(
                my.astype("Int64").astype(str).str.zfill(6) + "01",
                format="%Y%m%d",
                errors="coerce"
            )
            event_date.loc[missing] = fallback

    return event_date


def strict_dyad_filter(df: pd.DataFrame) -> pd.DataFrame:
    """
    严格 dyad：
    仅保留 Actor1CountryCode / Actor2CountryCode 明确为：
    - CHN 与 25 国之一
    - 或 25 国之一 与 CHN
    """
    a1 = to_series_str(df["Actor1CountryCode"])
    a2 = to_series_str(df["Actor2CountryCode"])

    mask = (
        ((a1 == CHINA_CODE) & (a2.isin(TARGET_CODES_SET))) |
        ((a2 == CHINA_CODE) & (a1.isin(TARGET_CODES_SET)))
    )

    out = df.loc[mask].copy()
    out["Direction"] = pd.NA
    out.loc[(to_series_str(out["Actor1CountryCode"]) == CHINA_CODE), "Direction"] = "CHN->Partner"
    out.loc[(to_series_str(out["Actor2CountryCode"]) == CHINA_CODE), "Direction"] = "Partner->CHN"
    return out


# ============================================================
# 8) 子进程任务：处理单个 ZIP
# ============================================================

def process_one_zip(zip_path_str: str) -> Dict:
    zip_path = Path(zip_path_str)
    pkg = infer_package_info(zip_path.name)

    result = {
        "zip_name": zip_path.name,
        "zip_path": str(zip_path),
        "package_type": pkg.package_type,
        "package_start": pkg.start,
        "package_end": pkg.end,
        "package_token": pkg.token,
        "status": "skip",
        "message": "",
        "fields": 0,
        "member": "",
        "raw_rows": 0,
        "date_valid_rows": 0,
        "kept_rows": 0,
        "chn_as_actor1": 0,
        "chn_as_actor2": 0,
        "partner_rows": 0,
        "filtered_df": None,
        "partner_counts": {},
        "year_counts": {},
    }

    # 1) 文件名无法识别日期
    if pd.isna(pkg.start) or pd.isna(pkg.end):
        result["message"] = "无法从文件名识别年/月/日包日期范围"
        return result

    # 2) 文件包与研究期不重叠
    if not overlap(pkg.start, pkg.end, START_DATE, END_DATE):
        result["message"] = "文件包日期范围不在研究区间内"
        return result

    try:
        # 3) 读取 ZIP
        df, field_count, member = read_gdelt_zip(zip_path)
        result["fields"] = field_count
        result["member"] = member
        result["raw_rows"] = len(df)

        if df.empty:
            result["status"] = "ok"
            result["message"] = "空文件"
            return result

        # 4) 补充事件日期
        df["EventDate"] = parse_event_date(df)

        # 5) 按真实事件日期再过滤一次，避免年包/月包里混入边界之外记录
        in_date = df["EventDate"].between(START_DATE, END_DATE, inclusive="both")
        df_date = df.loc[in_date].copy()
        result["date_valid_rows"] = len(df_date)

        if df_date.empty:
            result["status"] = "ok"
            result["message"] = "日期过滤后无记录"
            return result

        # 6) 严格 dyad 过滤
        filtered = strict_dyad_filter(df_date)
        result["kept_rows"] = len(filtered)

        if filtered.empty:
            result["status"] = "ok"
            result["message"] = "无严格 dyad 命中"
            return result

        # 7) 统计方向与伙伴国
        a1 = to_series_str(filtered["Actor1CountryCode"])
        a2 = to_series_str(filtered["Actor2CountryCode"])
        result["chn_as_actor1"] = int((a1 == CHINA_CODE).sum())
        result["chn_as_actor2"] = int((a2 == CHINA_CODE).sum())
        result["partner_rows"] = int(len(filtered))

        partner_code = a2.where(a1 == CHINA_CODE, a1)
        result["partner_counts"] = partner_code.value_counts(dropna=False).to_dict()

        # 年度分布
        year_series = filtered["EventDate"].dt.year
        result["year_counts"] = year_series.value_counts().sort_index().to_dict()

        # 8) 输出统一列
        for col in KEEP_COLS:
            if col not in filtered.columns:
                filtered[col] = pd.NA

        filtered["SourceZip"] = zip_path.name
        filtered["PackageType"] = pkg.package_type
        filtered["PackageStart"] = pkg.start.strftime("%Y-%m-%d")
        filtered["PackageEnd"] = pkg.end.strftime("%Y-%m-%d")

        # 保留统一列
        filtered = filtered[KEEP_COLS].copy()

        result["filtered_df"] = filtered
        result["status"] = "ok"
        result["message"] = "完成"
        return result

    except zipfile.BadZipFile:
        result["status"] = "error"
        result["message"] = "ZIP 文件损坏"
        return result
    except Exception as e:
        result["status"] = "error"
        result["message"] = f"{type(e).__name__}: {e}"
        return result


# ============================================================
# 9) 主程序
# ============================================================

def main():
    sys.stdout = DualLogger(LOG_TXT)

    print("=" * 90)
    print("GDELT 本地 ZIP 严格双边关系检索（中国 × 图中 25 个国家）")
    print("=" * 90)
    print(f"研究区间: {START_DATE.date()} ~ {END_DATE.date()}")
    print(f"ZIP 目录: {ZIP_DIR}")
    print(f"输出目录: {SAVE_DIR}")
    print(f"进程数: {MAX_WORKERS}")
    print(f"日志文件: {LOG_TXT}")
    print(f"逐文件明细: {FILE_REPORT_CSV}")
    print(f"汇总 TXT: {SUMMARY_TXT}")
    print(f"最终 CSV: {FINAL_CSV}")
    print()

    print("目标国家代码表：")
    for cn_name, code in TARGET_COUNTRY_CODES.items():
        print(f"  - {cn_name:<20s} -> {code}")
    print(f"  - China -> {CHINA_CODE}")
    print()

    zip_dir = Path(ZIP_DIR)
    all_zip_files = sorted(zip_dir.rglob("*.zip"))
    print(f"发现 ZIP 文件总数: {len(all_zip_files)}")

    # 先按文件名推断包范围，再筛掉完全不相关的包
    candidates = []
    skipped_by_name = 0
    for zp in all_zip_files:
        pkg = infer_package_info(zp.name)
        if pd.isna(pkg.start) or pd.isna(pkg.end):
            skipped_by_name += 1
            continue
        if overlap(pkg.start, pkg.end, START_DATE, END_DATE):
            candidates.append(zp)

    print(f"可进入检索的 ZIP 数量: {len(candidates)}")
    print(f"因文件名无法识别日期而跳过: {skipped_by_name}")
    print()

    if not candidates:
        print("没有发现可处理的 ZIP 文件，程序结束。")
        return

    # 清理旧文件
    for p in [FINAL_CSV, FILE_REPORT_CSV, SUMMARY_TXT]:
        if os.path.exists(p):
            os.remove(p)
            print(f"已删除旧文件: {p}")

    mp.freeze_support()

    total_raw_rows = 0
    total_date_valid_rows = 0
    total_kept_rows = 0
    total_chn_as_actor1 = 0
    total_chn_as_actor2 = 0

    partner_counter: Dict[str, int] = {}
    year_counter: Dict[int, int] = {}
    file_rows = []

    header_written = False

    print("开始并行处理...")
    print()

    with ProcessPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_map = {executor.submit(process_one_zip, str(zp)): zp for zp in candidates}

        done = 0
        for future in as_completed(future_map):
            zp = future_map[future]
            done += 1

            try:
                r = future.result()
            except Exception as e:
                print(f"[{done}/{len(candidates)}] {zp.name} -> 子进程异常：{e}")
                continue

            total_raw_rows += r["raw_rows"]
            total_date_valid_rows += r["date_valid_rows"]
            total_kept_rows += r["kept_rows"]
            total_chn_as_actor1 += r["chn_as_actor1"]
            total_chn_as_actor2 += r["chn_as_actor2"]

            # 汇总伙伴国计数
            for k, v in r["partner_counts"].items():
                if pd.isna(k):
                    continue
                partner_counter[str(k)] = partner_counter.get(str(k), 0) + int(v)

            # 汇总年度计数
            for k, v in r["year_counts"].items():
                year_counter[int(k)] = year_counter.get(int(k), 0) + int(v)

            file_rows.append({
                "zip_name": r["zip_name"],
                "package_type": r["package_type"],
                "package_start": r["package_start"],
                "package_end": r["package_end"],
                "fields": r["fields"],
                "member": r["member"],
                "raw_rows": r["raw_rows"],
                "date_valid_rows": r["date_valid_rows"],
                "kept_rows": r["kept_rows"],
                "chn_as_actor1": r["chn_as_actor1"],
                "chn_as_actor2": r["chn_as_actor2"],
                "status": r["status"],
                "message": r["message"],
            })

            # 输出详细步骤
            if r["status"] == "ok":
                print(
                    f"[{done}/{len(candidates)}] {r['zip_name']} | "
                    f"{r['package_type']} {r['package_start'].strftime('%Y-%m-%d')}~{r['package_end'].strftime('%Y-%m-%d')} | "
                    f"字段数={r['fields']} | 原始行数={r['raw_rows']} | 日期有效={r['date_valid_rows']} | 命中={r['kept_rows']}"
                )

                if r["kept_rows"] > 0:
                    top_partners = sorted(r["partner_counts"].items(), key=lambda x: x[1], reverse=True)[:5]
                    top_partner_str = ", ".join([f"{k}:{v}" for k, v in top_partners])
                    print(f"    方向统计: CHN在Actor1={r['chn_as_actor1']}，CHN在Actor2={r['chn_as_actor2']}")
                    print(f"    命中伙伴国Top5: {top_partner_str}")
                    print(f"    说明: {r['message']}")

                    if r["filtered_df"] is not None and not r["filtered_df"].empty:
                        mode = "a" if APPEND_WRITE else "w"
                        r["filtered_df"].to_csv(
                            FINAL_CSV,
                            mode=mode,
                            header=not header_written,
                            index=False,
                            encoding="utf-8-sig"
                        )
                        header_written = True
                else:
                    print(f"    说明: {r['message']}")
            else:
                print(
                    f"[{done}/{len(candidates)}] {r['zip_name']} | "
                    f"{r['status']} | {r['message']}"
                )

    # 文件明细表
    report_df = pd.DataFrame(file_rows)
    report_df = report_df.sort_values(["package_start", "zip_name"], na_position="last")
    report_df.to_csv(FILE_REPORT_CSV, index=False, encoding="utf-8-sig")

    # 总体汇总
    partner_df = pd.DataFrame(
        [{"PartnerCountryCode": k, "Count": v} for k, v in sorted(partner_counter.items(), key=lambda x: x[1], reverse=True)]
    )
    year_df = pd.DataFrame(
        [{"Year": k, "Count": v} for k, v in sorted(year_counter.items(), key=lambda x: x[0])]
    )

    with open(SUMMARY_TXT, "w", encoding="utf-8") as f:
        f.write("GDELT 本地 ZIP 严格双边关系检索汇总\n")
        f.write("=" * 80 + "\n")
        f.write(f"研究区间: {START_DATE.date()} ~ {END_DATE.date()}\n")
        f.write(f"ZIP 目录: {ZIP_DIR}\n")
        f.write(f"输出目录: {SAVE_DIR}\n")
        f.write(f"最终 CSV: {FINAL_CSV}\n")
        f.write(f"逐文件明细 CSV: {FILE_REPORT_CSV}\n")
        f.write(f"总读取原始行数: {total_raw_rows}\n")
        f.write(f"日期有效行数: {total_date_valid_rows}\n")
        f.write(f"最终命中行数: {total_kept_rows}\n")
        f.write(f"Actor1 为 CHN 的命中数: {total_chn_as_actor1}\n")
        f.write(f"Actor2 为 CHN 的命中数: {total_chn_as_actor2}\n")
        f.write("\n")
        f.write("目标国家代码表:\n")
        for cn_name, code in TARGET_COUNTRY_CODES.items():
            f.write(f"  - {cn_name} -> {code}\n")
        f.write(f"  - China -> {CHINA_CODE}\n")
        f.write("\n")
        f.write("按伙伴国汇总（按命中数降序）：\n")
        if partner_df.empty:
            f.write("  无\n")
        else:
            for _, row in partner_df.iterrows():
                f.write(f"  - {row['PartnerCountryCode']}: {int(row['Count'])}\n")
        f.write("\n")
        f.write("按年份汇总：\n")
        if year_df.empty:
            f.write("  无\n")
        else:
            for _, row in year_df.iterrows():
                f.write(f"  - {int(row['Year'])}: {int(row['Count'])}\n")

    # 控制台收尾
    print()
    print("=" * 90)
    print("处理完成")
    print("=" * 90)
    print(f"总原始行数: {total_raw_rows}")
    print(f"日期有效行数: {total_date_valid_rows}")
    print(f"最终命中行数: {total_kept_rows}")
    print(f"Actor1 为 CHN 的命中数: {total_chn_as_actor1}")
    print(f"Actor2 为 CHN 的命中数: {total_chn_as_actor2}")
    print(f"最终 CSV: {FINAL_CSV}")
    print(f"逐文件明细 CSV: {FILE_REPORT_CSV}")
    print(f"汇总 TXT: {SUMMARY_TXT}")
    print(f"日志 TXT: {LOG_TXT}")


if __name__ == "__main__":
    main()
