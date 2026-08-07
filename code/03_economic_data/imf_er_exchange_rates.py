import pandas as pd
import numpy as np
from world_economic_outlook import er
import time
import os


# ========================== 配置区域 ==========================
# 输出目录
OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 时间范围
START_YEAR = "2002"
END_YEAR = "2025"

# 汇率指标代码（本币/美元）
INDICATOR = "XDC_USD"

# 两种汇率口径
TRANSFORMATIONS = {
    "PA_RT": "Period_Average",    # 期间平均汇率（与IMF DOTS贸易数据口径一致）
    "EOP_RT": "End_of_Period",    # 期末汇率
}

# 非欧元区国家：ISO-2代码 → 英文名称
COUNTRIES_NON_EURO = {
    "AU": "Australia",
    "BR": "Brazil",
    "CA": "Canada",
    "CN": "China",
    "IN": "India",
    "ID": "Indonesia",
    "IR": "Iran",
    "JP": "Japan",
    "MY": "Malaysia",
    "MX": "Mexico",
    "PH": "Philippines",
    "RU": "Russia",
    "SA": "Saudi Arabia",
    "SG": "Singapore",
    "KR": "South Korea",
    "TH": "Thailand",
    "AE": "United Arab Emirates",
    "GB": "United Kingdom",
    "US": "United States",
    "VN": "Vietnam",
}

# 欧元区国家（共享欧元汇率）
EURO_COUNTRIES = {
    "DE": "Germany",
    "FR": "France",
    "IT": "Italy",
    "NL": "Netherlands",
    "BE": "Belgium",
    "ES": "Spain",
}


# ========================== Step 1: 下载IMF ER数据（非欧元区） ==========================
def download_imf_er_non_euro():
    """从IMF Exchange Rate (ER) API下载非欧元区国家月度汇率。"""
    all_records = []

    print("=" * 70)
    print("Step 1: 从IMF ER API下载非欧元区国家汇率")
    print("=" * 70)

    for iso, name in COUNTRIES_NON_EURO.items():
        for tcode, tlabel in TRANSFORMATIONS.items():
            try:
                records = er(
                    isos=iso,
                    indicator=INDICATOR,
                    type_of_transformation=tcode,
                    frequency="M",
                    start_date=START_YEAR,
                    end_date=END_YEAR,
                    use_iso_alpha2=True,
                )
                for r in records:
                    all_records.append({
                        "ISO": iso,
                        "Country": name,
                        "YearMonth": r["date"][:7],          # 提取 "YYYY-MM"
                        "Rate_Type": tlabel,
                        "Frequency": r["frequency"],
                        "ExchangeRate": r["value"],
                    })
                print(f"  [OK] {name:<20} ({iso}) {tlabel:<15} : {len(records):>3} 条")
                time.sleep(0.2)
            except Exception as e:
                print(f"  [ERR] {name:<20} ({iso}) {tlabel:<15} : {str(e)[:60]}")

    df = pd.DataFrame(all_records)
    df["YearMonth"] = pd.to_datetime(df["YearMonth"])
    print(f"\n  IMF ER 非欧元区下载完成，共 {len(df)} 条记录。\n")
    return df


# ========================== Step 2: 从FRED下载EUR/USD并分配给欧元区国家 ==========================
def download_fred_eurusd():
    """
    从FRED下载美元/欧元日度汇率(DEXUSEU)，转换为月度EUR/USD，
    并复制给6个欧元区国家。
    """
    print("=" * 70)
    print("Step 2: 从FRED下载EUR/USD并分配给欧元区国家")
    print("=" * 70)

    # FRED直接CSV下载链接（无需API Key）
    fred_url = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=DEXUSEU"
    df_fred = pd.read_csv(fred_url, parse_dates=["observation_date"])

    # 计算 EUR/USD = 1 / (USD/EUR)
    df_fred["EUR_per_USD"] = 1.0 / df_fred["DEXUSEU"]
    df_fred["YearMonth"] = df_fred["observation_date"].dt.to_period("M")

    # 月度平均（Period Average）
    monthly_avg = (
        df_fred.groupby("YearMonth")["EUR_per_USD"]
        .mean()
        .reset_index()
    )
    monthly_avg["YearMonth_str"] = monthly_avg["YearMonth"].astype(str)

    # 月末值（End of Period）
    monthly_eop = (
        df_fred.groupby("YearMonth")
        .tail(1)[["YearMonth", "EUR_per_USD"]]
        .copy()
    )
    monthly_eop["YearMonth_str"] = monthly_eop["YearMonth"].astype(str)

    # 构建欧元区记录
    all_records = []
    for iso, name in EURO_COUNTRIES.items():
        # Period Average
        for _, row in monthly_avg.iterrows():
            if "2002-01" <= row["YearMonth_str"] <= "2025-12":
                all_records.append({
                    "ISO": iso,
                    "Country": name,
                    "YearMonth": row["YearMonth_str"],
                    "Rate_Type": "Period_Average",
                    "Frequency": "M",
                    "ExchangeRate": round(row["EUR_per_USD"], 6),
                })
        # End of Period
        for _, row in monthly_eop.iterrows():
            if "2002-01" <= row["YearMonth_str"] <= "2025-12":
                all_records.append({
                    "ISO": iso,
                    "Country": name,
                    "YearMonth": row["YearMonth_str"],
                    "Rate_Type": "End_of_Period",
                    "Frequency": "M",
                    "ExchangeRate": round(row["EUR_per_USD"], 6),
                })
        print(f"  [OK] {name:<20} ({iso}) : EUR/USD 已分配")

    df = pd.DataFrame(all_records)
    df["YearMonth"] = pd.to_datetime(df["YearMonth"])
    print(f"\n  欧元区汇率分配完成，共 {len(df)} 条记录。\n")
    return df


# ========================== Step 3: 合并与缺失值插值 ==========================
def merge_and_interpolate(df_imf, df_euro):
    """
    合并IMF数据与欧元区数据，对缺失值进行线性插值，
    生成完整面板（25国 × 288月 × 2种口径 = 14,976条）。
    """
    print("=" * 70)
    print("Step 3: 合并数据并进行缺失值线性插值")
    print("=" * 70)

    # 合并
    df_raw = pd.concat([df_imf, df_euro], ignore_index=True)
    df_raw = df_raw.sort_values(["Country", "Rate_Type", "YearMonth"]).reset_index(drop=True)

    # 保存原始版
    raw_path = os.path.join(OUTPUT_DIR, "IMF_ER_汇率_25国_月度_2002-2025.csv")
    df_raw.to_csv(raw_path, index=False, encoding="utf-8-sig")
    print(f"  原始数据已保存: {raw_path}")

    # 构建完整网格（确保每个国家-每个月-每种类型都有行）
    all_countries_meta = df_raw[["ISO", "Country"]].drop_duplicates().sort_values("ISO")
    all_dates = pd.date_range("2002-01-01", "2025-12-01", freq="MS")
    all_rate_types = list(TRANSFORMATIONS.values())

    idx = pd.MultiIndex.from_product(
        [all_countries_meta["ISO"].values, all_dates, all_rate_types],
        names=["ISO", "YearMonth", "Rate_Type"],
    )
    df_full = pd.DataFrame(index=idx).reset_index()
    df_full = df_full.merge(all_countries_meta, on="ISO", how="left")
    df_full["YearMonth"] = pd.to_datetime(df_full["YearMonth"])

    # 合并原始观测值
    df_merged = df_full.merge(
        df_raw[["ISO", "YearMonth", "Rate_Type", "ExchangeRate"]],
        on=["ISO", "YearMonth", "Rate_Type"],
        how="left",
    )

    # 按国家-类型分组线性插值
    interpolated_groups = []
    for (iso, rate_type), group in df_merged.groupby(["ISO", "Rate_Type"]):
        group = group.sort_values("YearMonth").copy()
        group["ExchangeRate_interp"] = group["ExchangeRate"].interpolate(method="linear")
        group["is_interpolated"] = group["ExchangeRate"].isna() & group["ExchangeRate_interp"].notna()
        interpolated_groups.append(group)

    df_final = pd.concat(interpolated_groups, ignore_index=True)
    df_final = df_final.sort_values(["Country", "Rate_Type", "YearMonth"]).reset_index(drop=True)
    df_final["Frequency"] = "M"

    # 整理输出列
    out = df_final[[
        "ISO", "Country", "YearMonth", "Rate_Type", "Frequency",
        "ExchangeRate", "ExchangeRate_interp", "is_interpolated"
    ]].copy()
    out["YearMonth"] = out["YearMonth"].dt.strftime("%Y-%m")
    out["ExchangeRate"] = out["ExchangeRate"].round(6)
    out["ExchangeRate_interp"] = out["ExchangeRate_interp"].round(6)

    # 保存完整版
    full_path = os.path.join(OUTPUT_DIR, "IMF_ER_汇率_25国_月度_2002-2025_完整版.csv")
    out.to_csv(full_path, index=False, encoding="utf-8-sig")
    print(f"  完整版已保存: {full_path}")

    # 打印完整性报告
    print("\n  --- 数据完整性报告 ---")
    for country in sorted(out["Country"].unique()):
        sub = out[out["Country"] == country]
        pa_count = len(sub[sub["Rate_Type"] == "Period_Average"])
        eop_count = len(sub[sub["Rate_Type"] == "End_of_Period"])
        interp_count = sub["is_interpolated"].sum()
        status = "✅ 完整" if interp_count == 0 else f"⚠️ 插值 {int(interp_count)} 条"
        print(f"  {country:<20} PA={pa_count:<3} EOP={eop_count:<3} | {status}")

    print(f"\n  总计: {len(out)} 条记录（26国 × 288月 × 2种口径）")
    return out


# ========================== 主程序 ==========================
if __name__ == "__main__":
    print("\n" + "=" * 70)
    print("IMF Exchange Rate (ER) 25国月度汇率下载脚本")
    print("=" * 70 + "\n")

    # Step 1
    df_imf = download_imf_er_non_euro()

    # Step 2
    df_euro = download_fred_eurusd()

    # Step 3
    df_complete = merge_and_interpolate(df_imf, df_euro)

    print("\n" + "=" * 70)
    print("全部完成！")
    print("=" * 70)
    print(f"\n请查看输出目录: {OUTPUT_DIR}")
    print("建议在你的PPMLHDFE回归中使用 'Period_Average' 口径，")
    print("并取对数 ln(ExchangeRate_interp) 作为控制变量。")
