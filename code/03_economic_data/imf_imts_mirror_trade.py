import requests
import pandas as pd
import time
import os
import sys

# 强制立即刷新输出，便于观察后台任务进度
sys.stdout.reconfigure(encoding='utf-8')
class FlushOutput:
    def __init__(self, stream):
        self.stream = stream
    def write(self, msg):
        self.stream.write(msg)
        self.stream.flush()
    def flush(self):
        self.stream.flush()
    def __getattr__(self, name):
        return getattr(self.stream, name)
sys.stdout = FlushOutput(sys.stdout)

# ========================== 配置区域 ==========================
API_KEY = os.environ.get("COMTRADE_API_KEY", "")  #（在 comtrade.un.org 免费注册申请）
PARTNER_CODE_CHN = "156"  # 中国在 UN Comtrade 中的代码

# 25个目标伙伴国 (名称, UN Comtrade代码, ISO-3代码)
COUNTRY_LIST = [
    ("United States", "842", "USA"),
    ("Japan", "392", "JPN"),
    ("South Korea", "410", "KOR"),
    ("Germany", "276", "DEU"),
    ("United Kingdom", "826", "GBR"),
    ("Singapore", "702", "SGP"),
    ("Malaysia", "458", "MYS"),
    ("France", "250", "FRA"),
    ("Canada", "124", "CAN"),
    ("Australia", "36", "AUS"),
    ("Italy", "380", "ITA"),
    ("Netherlands", "528", "NLD"),
    ("Thailand", "764", "THA"),
    ("Russia", "643", "RUS"),
    ("Indonesia", "360", "IDN"),
    ("Mexico", "484", "MEX"),
    ("Belgium", "56", "BEL"),
    ("Spain", "724", "ESP"),
    ("Philippines", "608", "PHL"),
    ("Saudi Arabia", "682", "SAU"),
    ("India", "356", "IND"),
    ("Brazil", "76", "BRA"),
    ("United Arab Emirates", "784", "ARE"),
    ("Iran", "364", "IRN"),
    ("Vietnam", "704", "VNM"),
]

START_YEAR = 2002
END_YEAR = 2025

OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\经济数据库\IMF"
CSV_FILENAME = "IMTS_伙伴国视角对华贸易_25国_月度_2002-2025.csv"

API_BASE_URL = "https://comtradeapi.un.org/data/v1/get/C/M/HS"
MAX_RETRIES = 3
RETRY_DELAY = 5
REQUEST_DELAY = 1.5
# ===============================================================


def fetch_trade_data(reporter_code, reporter_name, periods):
    """
    从 UN Comtrade API 获取单个国家的对华贸易数据。
    reporter_code: 伙伴国的 UN Comtrade 代码
    reporter_name: 伙伴国名称
    periods: 逗号分隔的月份字符串，如 "202001,202002,..."
    """
    params = {
        "reporterCode": reporter_code,
        "partnerCode": PARTNER_CODE_CHN,
        "period": periods,
        "cmdCode": "TOTAL",
        "flowCode": "M,X",  # M=Imports(伙伴国从中国进口), X=Exports(伙伴国向中国出口)
        "key": API_KEY,
    }

    for attempt in range(MAX_RETRIES):
        try:
            resp = requests.get(API_BASE_URL, params=params, timeout=60)
            resp.raise_for_status()
            data = resp.json()
            records = data.get("data", [])
            if records:
                return pd.DataFrame(records)
            else:
                print(f"   [WARN] {reporter_name} {periods[:7]}..{periods[-6:]} 无数据返回")
                return pd.DataFrame()
        except requests.exceptions.RequestException as e:
            print(f"   [WARN] 请求失败 ({attempt+1}/{MAX_RETRIES}): {str(e)[:60]}")
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAY)
            else:
                print(f"   [ERR] 达到最大重试次数，跳过")
                return pd.DataFrame()


def build_full_grid():
    """生成完整的时间-国家网格（25国 × 288月）"""
    rows = []
    all_months = pd.period_range(start=f"{START_YEAR}-01", end=f"{END_YEAR}-12", freq="M")
    for name, un_code, iso3 in COUNTRY_LIST:
        for month in all_months:
            rows.append({
                "ISO": iso3,
                "Country": name,
                "YearMonth": month.strftime("%Y-%m"),
                "Year": month.year,
                "Month": month.month,
            })
    return pd.DataFrame(rows)


def main():
    print("=" * 70)
    print("伙伴国视角对华贸易数据下载 (UN Comtrade API)")
    print("=" * 70)
    print(f"目标: 25个伙伴国各自报告的 对华出口(FOB) / 从中国进口(CIF)")
    print(f"时间: {START_YEAR}-01 至 {END_YEAR}-12 (月度)")
    print(f"输出: {os.path.join(OUTPUT_DIR, CSV_FILENAME)}")
    print("=" * 70 + "\n")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 逐国逐年下载
    all_raw = []
    for name, un_code, iso3 in COUNTRY_LIST:
        print(f"处理 {name} ({iso3}) ...")
        for year in range(START_YEAR, END_YEAR + 1):
            periods = ",".join([f"{year}{m:02d}" for m in range(1, 13)])
            df_year = fetch_trade_data(un_code, name, periods)
            if not df_year.empty:
                all_raw.append(df_year)
            time.sleep(REQUEST_DELAY)
        print(f"   [OK] {name} 完成")

    if not all_raw:
        print("\n[ERR] 未获取到任何数据，请检查 API 密钥和网络连接")
        return

    print("\n" + "=" * 70)
    print("数据整理中...")
    print("=" * 70)

    # 合并原始数据
    raw = pd.concat(all_raw, ignore_index=True)
    print(f"原始记录数: {len(raw)}")

    # 选择需要的列并重命名
    keep_cols = {
        "reporterCode": "reporter_un_code",
        "partnerCode": "partner_un_code",
        "period": "period",
        "refYear": "Year",
        "refMonth": "Month",
        "flowCode": "flow_code",
        "primaryValue": "trade_value_usd",
    }
    df = raw[list(keep_cols.keys())].rename(columns=keep_cols).copy()

    # 创建 ISO 和 Country 映射
    iso_map = {un_code: iso3 for _, un_code, iso3 in COUNTRY_LIST}
    name_map = {un_code: name for name, un_code, _ in COUNTRY_LIST}
    df["ISO"] = df["reporter_un_code"].astype(str).map(iso_map)
    df["Country"] = df["reporter_un_code"].astype(str).map(name_map)
    df["YearMonth"] = df["period"].astype(str).str[:4] + "-" + df["period"].astype(str).str[4:6]

    # 透视: 宽格式 (每个国家-月份一行, 进口/出口两列)
    pivot = df.pivot_table(
        index=["ISO", "Country", "YearMonth", "Year", "Month"],
        columns="flow_code",
        values="trade_value_usd",
        aggfunc="first",
    ).reset_index()

    # flow_code M = Imports (伙伴国从中国进口) = 中国向伙伴国出口
    # flow_code X = Exports (伙伴国向中国出口) = 中国从伙伴国进口
    pivot = pivot.rename(columns={
        "M": "Import_from_CHN",
        "X": "Export_to_CHN",
    })

    # 确保两列都存在
    if "Import_from_CHN" not in pivot.columns:
        pivot["Import_from_CHN"] = pd.NA
    if "Export_to_CHN" not in pivot.columns:
        pivot["Export_to_CHN"] = pd.NA

    # 计算总贸易额
    pivot["Trade_Total"] = pivot["Import_from_CHN"].fillna(0) + pivot["Export_to_CHN"].fillna(0)

    # 与完整网格合并，确保每个国家×每个月都有行（NA表示数据缺失）
    grid = build_full_grid()
    grid["Year"] = grid["Year"].astype(int)
    grid["Month"] = grid["Month"].astype(int)
    grid["YearMonth_dt"] = pd.to_datetime(grid["YearMonth"])

    result = grid.merge(
        pivot[["ISO", "YearMonth", "Import_from_CHN", "Export_to_CHN", "Trade_Total"]],
        on=["ISO", "YearMonth"],
        how="left",
    )

    # 整理列顺序
    result = result[[
        "ISO", "Country", "YearMonth", "Year", "Month",
        "Import_from_CHN", "Export_to_CHN", "Trade_Total"
    ]].sort_values(["ISO", "YearMonth"]).reset_index(drop=True)

    # 保存
    csv_path = os.path.join(OUTPUT_DIR, CSV_FILENAME)
    result.to_csv(csv_path, index=False, encoding="utf-8-sig")

    print(f"\n[OK] 数据已保存: {csv_path}")
    print(f"   总行数: {len(result)} (25国 × 288月 = 7,200)")
    print(f"   列: {list(result.columns)}")

    # 完整性报告
    print("\n" + "=" * 70)
    print("数据完整性报告")
    print("=" * 70)
    for iso in sorted(result["ISO"].unique()):
        sub = result[result["ISO"] == iso]
        imp_miss = sub["Import_from_CHN"].isna().sum()
        exp_miss = sub["Export_to_CHN"].isna().sum()
        status = "[OK] 完整" if (imp_miss == 0 and exp_miss == 0) else f"[MISS] M={imp_miss} X={exp_miss}"
        print(f"  {iso:<5} | {sub['Country'].iloc[0]:<25} | {status}")

    print("\n" + "=" * 70)
    print("说明:")
    print("  Import_from_CHN = 伙伴国从中国进口 (CIF) ≈ 中国视角的 Exports_to_Partner (FOB)")
    print("  Export_to_CHN   = 伙伴国向中国出口 (FOB) ≈ 中国视角的 Imports_from_Partner (CIF)")
    print("  Trade_Total     = Import_from_CHN + Export_to_CHN")
    print("=" * 70)


if __name__ == "__main__":
    main()
