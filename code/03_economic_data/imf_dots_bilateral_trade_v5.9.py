import sdmx
import pandas as pd
import time
import os

# ==================== 配置 ====================
output_dir = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\经济数据库\IMF"
os.makedirs(output_dir, exist_ok=True)
csv_path = os.path.join(output_dir, "china_bilateral_trade_monthly.csv")

reporter_code = "CN"
reporter_name = "China"
reporter_iso = "CHN"

partner_codes = {
    "USA": "US", "JPN": "JP", "KOR": "KR", "DEU": "DE", "GBR": "GB",
    "SGP": "SG", "MYS": "MY", "FRA": "FR", "CAN": "CA", "AUS": "AU",
    "ITA": "IT", "NLD": "NL", "THA": "TH", "RUS": "RU", "IDN": "ID",
    "MEX": "MX", "BEL": "BE", "ESP": "ES", "PHL": "PH", "SAU": "SA",
    "IND": "IN", "BRA": "BR", "ARE": "AE", "IRN": "IR", "VNM": "VN"
}

partner_names = {
    "USA": "United States", "JPN": "Japan", "KOR": "South Korea",
    "DEU": "Germany", "GBR": "United Kingdom", "SGP": "Singapore",
    "MYS": "Malaysia", "FRA": "France", "CAN": "Canada",
    "AUS": "Australia", "ITA": "Italy", "NLD": "Netherlands",
    "THA": "Thailand", "RUS": "Russia", "IDN": "Indonesia",
    "MEX": "Mexico", "BEL": "Belgium", "ESP": "Spain",
    "PHL": "Philippines", "SAU": "Saudi Arabia", "IND": "India",
    "BRA": "Brazil", "ARE": "United Arab Emirates",
    "IRN": "Iran", "VNM": "Vietnam"
}

indicator_export = "TXG_FOB_USD"
indicator_import = "TMG_CIF_USD"
frequency = "M"
start = "2002-01"
end = "2025-12"

# ==================== 连接 IMF SDMX API ====================
client = sdmx.Client("IMF_DATA")

def fetch_trade_series(partner_imf, indicator):
    key = f"{reporter_code}.{indicator}.{partner_imf}.{frequency}"
    try:
        msg = client.data(
            "IMTS",
            key=key,
            params={"startPeriod": start, "endPeriod": end}
        )
        df = sdmx.to_pandas(msg)
        if df.empty:
            return pd.Series(dtype="float64")
        if isinstance(df, pd.DataFrame):
            series = df.iloc[:, 0]
        else:
            series = df
        if not isinstance(series.index, pd.PeriodIndex):
            series.index = pd.PeriodIndex(series.index, freq="M")
        series.name = indicator
        return series
    except Exception as e:
        print(f"   ⚠️ 获取失败 [{partner_imf} / {indicator}]: {e}")
        return pd.Series(dtype="float64")

# ==================== 生成完整的时间网格 ====================
all_months = pd.period_range(start=start, end=end, freq="M")
rows = []
for iso3, imf2 in partner_codes.items():
    for month in all_months:
        rows.append({
            "reporter": reporter_name,
            "reporter_iso": reporter_iso,
            "partner": partner_names[iso3],
            "partner_iso": iso3,
            "year": month.year,
            "month": month.month
        })
grid = pd.DataFrame(rows)

# ==================== 下载并合并数据 ====================
print("开始下载数据...")
export_data = {}
import_data = {}

for iso3, imf2 in partner_codes.items():
    print(f"处理 {partner_names[iso3]} ({iso3}/{imf2}) ...")
    exp_series = fetch_trade_series(imf2, indicator_export)
    export_data[iso3] = exp_series
    imp_series = fetch_trade_series(imf2, indicator_import)
    import_data[iso3] = imp_series
    time.sleep(0.5)

def get_value(iso3, month, data_dict):
    series = data_dict.get(iso3)
    if series is None or series.empty:
        return None
    try:
        val = series.get(month)
        return val if pd.notna(val) else None
    except KeyError:
        return None

print("正在整理数据...")
export_col = []
import_col = []
for _, row in grid.iterrows():
    iso3 = row["partner_iso"]
    month = pd.Period(year=row["year"], month=row["month"], freq="M")
    exp_val = get_value(iso3, month, export_data)
    imp_val = get_value(iso3, month, import_data)
    export_col.append(exp_val)
    import_col.append(imp_val)

grid["export_fob_usd"] = export_col
grid["import_cif_usd"] = import_col

grid["trade_balance_usd"] = grid.apply(
    lambda row: row["export_fob_usd"] - row["import_cif_usd"]
    if (pd.notna(row["export_fob_usd"]) and pd.notna(row["import_cif_usd"]))
    else None,
    axis=1
)

# ==================== 保存 CSV ====================
grid.to_csv(csv_path, index=False, na_rep="NA", encoding="utf-8-sig")
print(f"\n✅ 数据已保存至：{csv_path}")
print(f"共 {len(grid)} 行，列：{list(grid.columns)}")
