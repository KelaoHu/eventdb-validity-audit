from __future__ import annotations

import math
import time
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence

import pandas as pd
import requests


# ============================================================
# 用户设置
# ============================================================

PRIMARY_KEY = "2bdd017518a94ed48806399fcd9ec216"
SECONDARY_KEY = "68c62c868d9940aba0ee3cdb4571ab29"

OUTPUT_DIR = Path(r"C:\Users\胡克劳\Desktop\科研经济数据库\UN Comtrade")
OUTPUT_FILE = OUTPUT_DIR / "UN_Comtrade_China_Top25_Bilateral_Trade_2014_primary_cif_fob复现.csv"

# UN Comtrade API 设置
BASE_URL = "https://comtradeapi.un.org/data/v1/get/C/A/HS"
AUTH_MODE = "query"  # 可选："query" 或 "header"
TIMEOUT_SECONDS = 90
MAX_RETRIES = 10

# 查询参数
CMD_CODE = "TOTAL"
INCLUDE_DESC = "true"
CUSTOMS_CODE = "C00"
MOT_CODE = 0
PARTNER2_CODE = 0

# 国家代码
CHINA_CODE = 156

# 统计范围
REPORT_YEAR = "2014"

# 排除对象（中国、香港、澳门、台湾省）
EXCLUDE_PARTNER_CODES = {156, 344, 446, 158}

# 名称排除关键词
EXCLUDE_NAME_KEYWORDS = [
    "hong kong",
    "macao",
    "macau",
    "taiwan",
    "province of china",
    "china, hong kong",
    "china, macao",
    "china, macau",
    "china, taiwan",
]

# 常见聚合项
AGGREGATE_NAME_KEYWORDS = [
    "world",
    "areas, nes",
    "countries, nes",
    "unknown",
    "special categories",
    "eu-27",
    "european union",
    "europe",
    "africa",
    "asia",
    "americas",
    "oceania",
]


# ============================================================
# 工具函数
# ============================================================

def normalize_col(name: str) -> str:
    """把列名标准化，便于兼容接口中的不同写法。"""
    return "".join(ch for ch in str(name).lower() if ch.isalnum())


def safe_float(x: Any) -> Optional[float]:
    """安全转换为浮点数。"""
    if x is None:
        return None
    if isinstance(x, bool):
        return None
    if isinstance(x, (int, float)):
        if isinstance(x, float) and math.isnan(x):
            return None
        return float(x)
    s = str(x).strip().replace(",", "")
    if s == "" or s.lower() in {"na", "nan", "null", "none", "n/a"}:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def is_blank_or_match(text: Any, patterns: Sequence[str]) -> bool:
    """判断文本是否命中任一关键字。"""
    s = str(text or "").lower()
    return any(p in s for p in patterns)


def extract_records(payload: Any) -> List[Dict[str, Any]]:
    """兼容常见 API 返回结构，提取记录列表。"""
    if isinstance(payload, list):
        return payload

    if isinstance(payload, dict):
        for key in ("data", "dataset", "results", "items", "value"):
            val = payload.get(key)
            if isinstance(val, list):
                return val

        for val in payload.values():
            if isinstance(val, list):
                return val

    raise ValueError(f"无法识别的响应结构：{type(payload)}")


def request_json(
    session: requests.Session,
    url: str,
    params: Dict[str, Any],
    api_keys: Sequence[str],
) -> Any:
    """
    发送请求，带重试机制，并支持 query-string 或 header 两种认证方式。
    依次尝试 PRIMARY_KEY 和 SECONDARY_KEY。
    """
    last_error: Optional[Exception] = None
    keys = [k for k in api_keys if k]
    if not keys:
        keys = [""]

    for api_key in keys:
        if api_key:
            print(f"    正在尝试 API Key：{api_key[:6]}***")
        else:
            print("    未提供 API Key，尝试匿名请求（若接口不允许则会失败）")

        for attempt in range(1, MAX_RETRIES + 1):
            try:
                req_params = dict(params)
                headers: Dict[str, str] = {}

                if api_key:
                    if AUTH_MODE.lower() == "header":
                        headers["Ocp-Apim-Subscription-Key"] = api_key
                    else:
                        req_params["subscription-key"] = api_key

                print(f"    第 {attempt}/{MAX_RETRIES} 次请求中...")
                resp = session.get(url, params=req_params, headers=headers, timeout=TIMEOUT_SECONDS)

                if resp.status_code == 400:
                    print("    收到 400 错误，接口参数有问题，立即停止重试。")
                    print(f"    返回内容：{resp.text[:800]}")
                    resp.raise_for_status()

                if resp.status_code in {429, 500, 502, 503, 504}:
                    print(f"    服务器返回 {resp.status_code}，准备重试...")
                    time.sleep(min(60, 2 ** attempt))
                    continue

                resp.raise_for_status()
                print("    请求成功。")
                return resp.json()

            except Exception as e:
                last_error = e
                print(f"    请求失败：{e}")
                time.sleep(min(30, 2 ** attempt))

    raise RuntimeError(f"请求在多次重试后仍失败。最后错误：{last_error}")


def build_request_params(
    reporter_code: int,
    flow_code: str,
    partner_code: Optional[Any] = None,
) -> Dict[str, Any]:
    """
    构造请求参数。
    对于“中国作为 reporter、抓全部伙伴”的场景，不传 partnerCode。
    """
    params = {
        "cmdCode": CMD_CODE,
        "reporterCode": reporter_code,
        "flowCode": flow_code,
        "period": REPORT_YEAR,
        "includeDesc": INCLUDE_DESC,
        "customsCode": CUSTOMS_CODE,
        "motCode": MOT_CODE,
        "partner2Code": PARTNER2_CODE,
    }
    if partner_code is not None:
        params["partnerCode"] = partner_code
    return params


def tidy_trade_rows(records: List[Dict[str, Any]]) -> pd.DataFrame:
    """
    把 Comtrade 返回结果整理成干净表格。
    兼容不同字段名和不同响应结构。
    """
    if not records:
        return pd.DataFrame()

    df = pd.DataFrame(records)
    df.columns = [normalize_col(c) for c in df.columns]

    # 核心字段
    reporter_code_col = next((c for c in df.columns if c in {"reportercode", "reporter"}), None)
    reporter_desc_col = next((c for c in df.columns if c in {"reporterdesc", "reportername"}), None)
    partner_code_col = next((c for c in df.columns if c in {"partnercode", "partner"}), None)
    partner_desc_col = next((c for c in df.columns if c in {"partnerdesc", "partnername"}), None)
    flow_code_col = next((c for c in df.columns if c in {"flowcode", "flow"}), None)
    flow_desc_col = next((c for c in df.columns if c in {"flowdesc", "flowname"}), None)
    period_col = next((c for c in df.columns if c in {"period", "timeperiod", "yearmonth", "yyyymm", "date"}), None)

    if partner_code_col is None:
        raise ValueError(f"无法定位 partnerCode 字段。当前列：{list(df.columns)}")

    # 数值字段
    primary_col = next((c for c in df.columns if c in {"primaryvalue", "tradevalueprimary", "primarytradevalue", "primaryval"}), None)
    cif_col = next((c for c in df.columns if c in {"cifvalue", "ciftradevalue", "cifval"}), None)
    fob_col = next((c for c in df.columns if c in {"fobvalue", "fobtradevalue", "fobval"}), None)

    # 长表结构字段
    value_type_col = next((c for c in df.columns if c in {"valuetype", "tradevaluetype", "valuetypecode", "valueitem"}), None)
    value_col = next((c for c in df.columns if c in {"tradevalue", "value", "amount"}), None)

    rename_map = {}
    if reporter_code_col:
        rename_map[reporter_code_col] = "reporter_code"
    if reporter_desc_col:
        rename_map[reporter_desc_col] = "reporter_name"
    if partner_code_col:
        rename_map[partner_code_col] = "partner_code"
    if partner_desc_col:
        rename_map[partner_desc_col] = "partner_name"
    if flow_code_col:
        rename_map[flow_code_col] = "flow_code"
    if flow_desc_col:
        rename_map[flow_desc_col] = "flow_name"
    if period_col:
        rename_map[period_col] = "period"

    out = df.rename(columns=rename_map).copy()

    # 宽表优先
    if primary_col or cif_col or fob_col:
        out["primary_value"] = out[primary_col] if primary_col else None
        out["cif_value"] = out[cif_col] if cif_col else None
        out["fob_value"] = out[fob_col] if fob_col else None

    # 长表兜底
    elif value_type_col and value_col:
        tmp = out.copy()
        tmp["value_type_norm"] = tmp[value_type_col].astype(str).str.lower().str.strip()
        tmp["value_num"] = tmp[value_col].map(safe_float)

        idx_cols = [
            c for c in [
                "period", "reporter_code", "reporter_name",
                "partner_code", "partner_name", "flow_code", "flow_name"
            ] if c in tmp.columns
        ]
        wide = (
            tmp.pivot_table(
                index=idx_cols,
                columns="value_type_norm",
                values="value_num",
                aggfunc="sum",
            )
            .reset_index()
        )

        lookup = {normalize_col(c): c for c in wide.columns}
        for target, aliases in {
            "primary_value": ["primary", "primary value", "trade value - primary"],
            "cif_value": ["cif", "cif value", "trade value - cif"],
            "fob_value": ["fob", "fob value", "trade value - fob"],
        }.items():
            found = None
            for alias in aliases:
                key = lookup.get(normalize_col(alias))
                if key is not None:
                    found = key
                    break
            wide[target] = wide[found] if found else None

        out = wide

    # 单值格式兜底
    else:
        out["primary_value"] = out[value_col] if value_col else None
        out["cif_value"] = None
        out["fob_value"] = None

    for col in ["primary_value", "cif_value", "fob_value"]:
        if col in out.columns:
            out[col] = out[col].map(safe_float)

    keep = [
        c for c in [
            "period",
            "reporter_code", "reporter_name",
            "partner_code", "partner_name",
            "flow_code", "flow_name",
            "primary_value", "cif_value", "fob_value"
        ] if c in out.columns
    ]

    return out[keep].copy()


def fetch_annual_bilateral(
    session: requests.Session,
    reporter_code: int,
    flow_code: str,
    partner_code: Optional[Any] = None,
    flow_label: str = "",
) -> pd.DataFrame:
    """
    抓取单个报告国、单个贸易流、年度数据。
    中国 reporter 全量抓取时，不传 partnerCode。
    """
    params = build_request_params(
        reporter_code=reporter_code,
        flow_code=flow_code,
        partner_code=partner_code,
    )

    print(
        f"\n  开始抓取：reporter={reporter_code}, "
        f"partner={partner_code if partner_code is not None else 'ALL'}, "
        f"flow={flow_code} ({flow_label})"
    )
    payload = request_json(session, BASE_URL, params, api_keys=[PRIMARY_KEY, SECONDARY_KEY])
    records = extract_records(payload)
    df = tidy_trade_rows(records)

    if df.empty:
        print("  本次请求没有返回有效数据。")
        return df

    if "flow_code" in df.columns:
        df = df[df["flow_code"].astype(str).str.upper() == flow_code.upper()].copy()

    if partner_code is not None and str(partner_code).lower() != "all":
        df["partner_code"] = int(partner_code)

    group_cols = [c for c in ["partner_code", "partner_name"] if c in df.columns]
    if not group_cols:
        raise ValueError("返回结果中找不到 partner 相关字段，无法继续。")

    value_cols = [c for c in ["primary_value", "cif_value", "fob_value"] if c in df.columns]
    if value_cols:
        df = df.groupby(group_cols, as_index=False)[value_cols].sum(min_count=1)

    if "partner_code" not in df.columns and partner_code is not None and str(partner_code).lower() != "all":
        df["partner_code"] = int(partner_code)

    df["flow_code"] = flow_code
    df["flow_label"] = flow_label

    print(f"  抓取完成：{len(df)} 个伙伴。")
    return df


def clean_partner_frame(df: pd.DataFrame) -> pd.DataFrame:
    """剔除中国、香港、澳门、台湾省以及常见聚合项。"""
    if df.empty:
        return df

    out = df.copy()

    if "partner_code" in out.columns:
        out = out[~out["partner_code"].isin(EXCLUDE_PARTNER_CODES)].copy()

    if "partner_name" in out.columns:
        out = out[
            ~out["partner_name"].map(
                lambda x: is_blank_or_match(x, EXCLUDE_NAME_KEYWORDS + AGGREGATE_NAME_KEYWORDS)
            )
        ].copy()
        out = out[out["partner_name"].notna()].copy()
        out = out[out["partner_name"].astype(str).str.strip() != ""].copy()

    return out.reset_index(drop=True)


def build_primary_ranking(session: requests.Session) -> pd.DataFrame:
    """
    以中国 reporter 口径构造 2014 年双边贸易总额前 25 名。
    主表以 primary 为准，同时保留 CIF/FOB 作为附表字段。
    """
    print("\n" + "=" * 72)
    print("第一步：抓取中国作为 reporter 的 2014 年双边贸易数据")
    print("=" * 72)

    exp_df = fetch_annual_bilateral(
        session=session,
        reporter_code=CHINA_CODE,
        flow_code="X",
        partner_code=None,
        flow_label="中国出口",
    )

    imp_df = fetch_annual_bilateral(
        session=session,
        reporter_code=CHINA_CODE,
        flow_code="M",
        partner_code=None,
        flow_label="中国进口",
    )

    if exp_df.empty or imp_df.empty:
        raise ValueError("中国 reporter 数据为空，无法生成排名。")

    exp_df = exp_df.rename(columns={
        "primary_value": "cn_export_primary",
        "cif_value": "cn_export_cif",
        "fob_value": "cn_export_fob",
        "partner_name": "partner_name_export",
    })
    imp_df = imp_df.rename(columns={
        "primary_value": "cn_import_primary",
        "cif_value": "cn_import_cif",
        "fob_value": "cn_import_fob",
        "partner_name": "partner_name_import",
    })

    merged = exp_df.merge(
        imp_df,
        on="partner_code",
        how="outer",
    )

    if "partner_name_export" in merged.columns and "partner_name_import" in merged.columns:
        merged["partner_name"] = merged["partner_name_export"].combine_first(merged["partner_name_import"])
    elif "partner_name_export" in merged.columns:
        merged["partner_name"] = merged["partner_name_export"]
    elif "partner_name_import" in merged.columns:
        merged["partner_name"] = merged["partner_name_import"]

    merged = clean_partner_frame(merged)
    merged = merged[merged["partner_code"] != CHINA_CODE].copy()

    numeric_cols = [
        "cn_export_primary", "cn_export_cif", "cn_export_fob",
        "cn_import_primary", "cn_import_cif", "cn_import_fob",
    ]
    for col in numeric_cols:
        if col in merged.columns:
            merged[col] = pd.to_numeric(merged[col], errors="coerce")

    merged["cn_trade_primary"] = merged["cn_export_primary"].fillna(0) + merged["cn_import_primary"].fillna(0)
    merged["cn_trade_cif"] = merged["cn_import_cif"].fillna(0)
    merged["cn_trade_fob"] = merged["cn_import_fob"].fillna(0)

    merged = merged.sort_values(["cn_trade_primary", "partner_code"], ascending=[False, True]).reset_index(drop=True)
    merged["rank"] = range(1, len(merged) + 1)

    top25 = merged.head(25).copy()

    print(f"中国 reporter 口径下，共识别到 {len(merged)} 个伙伴国家/地区。")
    print("前 25 名已筛出。")
    print(top25[["rank", "partner_code", "partner_name", "cn_export_primary", "cn_import_primary", "cn_trade_primary"]].to_string(index=False))

    return top25


def fetch_mirror_verification(session: requests.Session, partner_codes: Sequence[int]) -> pd.DataFrame:
    """
    对前 25 名伙伴做镜像检验：
    - 伙伴对中国出口 = 中国自该伙伴进口的镜像
    - 伙伴自中国进口 = 中国向该伙伴出口的镜像
    """
    print("\n" + "=" * 72)
    print("第二步：抓取前 25 名伙伴的镜像数据进行核验")
    print("=" * 72)

    frames: List[pd.DataFrame] = []
    total = len(partner_codes)

    for idx, partner_code in enumerate(partner_codes, start=1):
        print(f"\n  [{idx}/{total}] 正在处理伙伴代码：{partner_code}")

        partner_export_to_cn = fetch_annual_bilateral(
            session=session,
            reporter_code=partner_code,
            flow_code="X",
            partner_code=CHINA_CODE,
            flow_label="伙伴出口到中国",
        )
        partner_import_from_cn = fetch_annual_bilateral(
            session=session,
            reporter_code=partner_code,
            flow_code="M",
            partner_code=CHINA_CODE,
            flow_label="伙伴自中国进口",
        )

        if partner_export_to_cn.empty and partner_import_from_cn.empty:
            print("  该伙伴没有返回有效镜像数据。")
            continue

        if partner_export_to_cn.empty:
            partner_export_to_cn = pd.DataFrame({"partner_code": [partner_code]})
        if partner_import_from_cn.empty:
            partner_import_from_cn = pd.DataFrame({"partner_code": [partner_code]})

        if "partner_code" not in partner_export_to_cn.columns:
            partner_export_to_cn["partner_code"] = partner_code
        if "partner_code" not in partner_import_from_cn.columns:
            partner_import_from_cn["partner_code"] = partner_code

        partner_export_to_cn = partner_export_to_cn.rename(columns={
            "primary_value": "mirror_export_primary",
            "cif_value": "mirror_export_cif",
            "fob_value": "mirror_export_fob",
        })
        partner_import_from_cn = partner_import_from_cn.rename(columns={
            "primary_value": "mirror_import_primary",
            "cif_value": "mirror_import_cif",
            "fob_value": "mirror_import_fob",
        })

        one = partner_export_to_cn.merge(partner_import_from_cn, on="partner_code", how="outer")

        if "partner_name_x" in one.columns and "partner_name_y" in one.columns:
            one["mirror_partner_name"] = one["partner_name_x"].combine_first(one["partner_name_y"])
        elif "partner_name_x" in one.columns:
            one["mirror_partner_name"] = one["partner_name_x"]
        elif "partner_name_y" in one.columns:
            one["mirror_partner_name"] = one["partner_name_y"]
        else:
            one["mirror_partner_name"] = "China"

        for col in [
            "mirror_export_primary", "mirror_export_cif", "mirror_export_fob",
            "mirror_import_primary", "mirror_import_cif", "mirror_import_fob",
        ]:
            if col in one.columns:
                one[col] = pd.to_numeric(one[col], errors="coerce")

        one["partner_code"] = partner_code
        frames.append(one)

    if not frames:
        return pd.DataFrame()

    out = pd.concat(frames, ignore_index=True)

    keep_cols = [
        c for c in [
            "mirror_export_primary", "mirror_export_cif", "mirror_export_fob",
            "mirror_import_primary", "mirror_import_cif", "mirror_import_fob",
        ] if c in out.columns
    ]

    out = out.groupby(["partner_code"], as_index=False)[keep_cols].sum(min_count=1)

    print("镜像数据抓取完成。")
    return out


def build_final_table() -> pd.DataFrame:
    """构建最终输出表。"""
    print("=" * 72)
    print("UN Comtrade 2014 年中国双边贸易前 25 名程序开始运行")
    print("=" * 72)

    if not PRIMARY_KEY or "请在这里填写" in PRIMARY_KEY:
        raise SystemExit("请先在脚本顶部填写 PRIMARY_KEY 和 SECONDARY_KEY。")

    print(f"输出目录：{OUTPUT_DIR}")
    print(f"输出文件：{OUTPUT_FILE}")
    print(f"认证模式：{AUTH_MODE}")
    print(f"统计年份：{REPORT_YEAR}")
    print(f"排除对象代码：{sorted(EXCLUDE_PARTNER_CODES)}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0"})

    start_time = time.time()

    top25 = build_primary_ranking(session)
    mirror = fetch_mirror_verification(session, top25["partner_code"].tolist())

    print("\n" + "=" * 72)
    print("第三步：合并主表与镜像表")
    print("=" * 72)

    final_df = top25.merge(mirror, on="partner_code", how="left")

    for col in [
        "cn_export_primary", "cn_import_primary", "cn_trade_primary",
        "cn_export_cif", "cn_import_cif", "cn_export_fob", "cn_import_fob",
        "cn_trade_cif", "cn_trade_fob",
        "mirror_export_primary", "mirror_import_primary",
        "mirror_export_cif", "mirror_import_cif",
        "mirror_export_fob", "mirror_import_fob",
    ]:
        if col in final_df.columns:
            final_df[col] = pd.to_numeric(final_df[col], errors="coerce")

    final_df["diff_export_primary"] = final_df["cn_export_primary"] - final_df["mirror_import_primary"]
    final_df["diff_import_primary"] = final_df["cn_import_primary"] - final_df["mirror_export_primary"]
    final_df["diff_trade_primary"] = final_df["cn_trade_primary"] - (final_df["mirror_export_primary"] + final_df["mirror_import_primary"])

    final_df["diff_export_cif"] = final_df["cn_export_cif"] - final_df["mirror_import_cif"]
    final_df["diff_import_cif"] = final_df["cn_import_cif"] - final_df["mirror_export_cif"]
    final_df["diff_export_fob"] = final_df["cn_export_fob"] - final_df["mirror_export_fob"]
    final_df["diff_import_fob"] = final_df["cn_import_fob"] - final_df["mirror_import_fob"]

    ordered_cols = [
        "rank",
        "partner_code",
        "partner_name",

        "cn_export_primary",
        "cn_import_primary",
        "cn_trade_primary",

        "mirror_export_primary",
        "mirror_import_primary",
        "diff_export_primary",
        "diff_import_primary",
        "diff_trade_primary",

        "cn_export_cif",
        "cn_import_cif",
        "cn_export_fob",
        "cn_import_fob",
        "cn_trade_cif",
        "cn_trade_fob",

        "mirror_export_cif",
        "mirror_import_cif",
        "mirror_export_fob",
        "mirror_import_fob",

        "diff_export_cif",
        "diff_import_cif",
        "diff_export_fob",
        "diff_import_fob",
    ]

    for col in ordered_cols:
        if col not in final_df.columns:
            final_df[col] = pd.NA

    final_df = final_df[ordered_cols].copy()

    rename_map = {
        "rank": "rank_排名",
        "partner_code": "partner_code_伙伴国代码",
        "partner_name": "partner_name_伙伴国名称",

        "cn_export_primary": "cn_export_primary_中国向该国出口_主口径",
        "cn_import_primary": "cn_import_primary_中国自该国进口_主口径",
        "cn_trade_primary": "cn_trade_primary_中国双边贸易总额_主口径",

        "mirror_export_primary": "mirror_export_primary_伙伴国向中国出口_镜像主口径",
        "mirror_import_primary": "mirror_import_primary_伙伴国自中国进口_镜像主口径",
        "diff_export_primary": "diff_export_primary_中国出口减镜像进口_主口径",
        "diff_import_primary": "diff_import_primary_中国进口减镜像出口_主口径",
        "diff_trade_primary": "diff_trade_primary_中国总额减镜像总额_主口径",

        "cn_export_cif": "cn_export_cif_中国向该国出口_CIF",
        "cn_import_cif": "cn_import_cif_中国自该国进口_CIF",
        "cn_export_fob": "cn_export_fob_中国向该国出口_FOB",
        "cn_import_fob": "cn_import_fob_中国自该国进口_FOB",
        "cn_trade_cif": "cn_trade_cif_中国双边进口CIF汇总",
        "cn_trade_fob": "cn_trade_fob_中国双边进口FOB汇总",

        "mirror_export_cif": "mirror_export_cif_伙伴国向中国出口_CIF",
        "mirror_import_cif": "mirror_import_cif_伙伴国自中国进口_CIF",
        "mirror_export_fob": "mirror_export_fob_伙伴国向中国出口_FOB",
        "mirror_import_fob": "mirror_import_fob_伙伴国自中国进口_FOB",

        "diff_export_cif": "diff_export_cif_中国出口减镜像进口_CIF",
        "diff_import_cif": "diff_import_cif_中国进口减镜像出口_CIF",
        "diff_export_fob": "diff_export_fob_中国出口减镜像出口_FOB",
        "diff_import_fob": "diff_import_fob_中国进口减镜像进口_FOB",
    }

    final_df = final_df.rename(columns=rename_map)
    final_df = final_df.sort_values("rank_排名").reset_index(drop=True)

    elapsed = time.time() - start_time
    print("\n表格构建完成。")
    print(f"总耗时：{elapsed:.2f} 秒")
    print(f"将输出到：{OUTPUT_FILE}")

    return final_df


def main() -> None:
    """主入口。"""
    try:
        df = build_final_table()

        print("\n开始保存 CSV 文件...")
        df.to_csv(OUTPUT_FILE, index=False, encoding="utf-8-sig", float_format="%.2f", na_rep="")

        print("保存完成。")
        print(f"文件位置：{OUTPUT_FILE}")
        print(f"总行数：{len(df)}")

        print("\n前 5 行预览：")
        print(df.head(5).to_string(index=False))

        print("\n程序执行成功。")

    except Exception as e:
        print("\n程序执行失败。")
        print(f"错误信息：{e}")
        raise


if __name__ == "__main__":
    main()
