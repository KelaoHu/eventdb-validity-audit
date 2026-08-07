# IMF QNEA 季度GDP下载与月度插值脚本

import pandas as pd
import numpy as np
from world_economic_outlook import qnea
import requests
import time
import os


# ========================== 配置区域 ==========================
OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 25国ISO-2代码映射
COUNTRIES = {
    "AU": "Australia", "BE": "Belgium", "BR": "Brazil", "CA": "Canada", "CN": "China",
    "FR": "France", "DE": "Germany", "IN": "India", "ID": "Indonesia", "IR": "Iran",
    "IT": "Italy", "JP": "Japan", "MY": "Malaysia", "MX": "Mexico", "NL": "Netherlands",
    "PH": "Philippines", "RU": "Russia", "SA": "Saudi Arabia", "SG": "Singapore",
    "KR": "South Korea", "ES": "Spain", "TH": "Thailand", "AE": "United Arab Emirates",
    "GB": "United Kingdom", "US": "United States", "VN": "Vietnam",
}

# 需要World Bank补充的国家（IMF QNEA无季度GDP数据）
WORLDBANK_BACKFILL = ["AE", "VN"]


# ========================== Step 1: 下载IMF QNEA季度GDP ==========================
def download_qnea_gdp():
    """
    从IMF QNEA下载25国季度GDP数据。
    策略：优先SA（季节调整），其次NSA；优先V（名义值），其次Q（实际量）。
    """
    all_records = []
    print("=" * 70)
    print("Step 1: 从IMF QNEA下载季度GDP")
    print("=" * 70)

    for iso, name in COUNTRIES.items():
        if iso in WORLDBANK_BACKFILL:
            print(f"  [SKIP] {name:<20} ({iso}): 转由World Bank补充")
            continue

        downloaded = False
        # 策略矩阵：(price_type, s_adjustment)
        strategies = [
            ("V", "SA"), ("V", "NSA"), ("Q", "SA"), ("Q", "NSA")
        ]

        for pt, sa in strategies:
            if downloaded:
                break
            try:
                records = qnea(
                    isos=iso,
                    indicator="B1GQ",
                    price_type=pt,
                    s_adjustment=sa,
                    type_of_transformation="XDC",
                    frequency="Q",
                    start_date="2002-01-01",
                    end_date="2025-12-31",
                    use_iso_alpha2=True,
                )
                if records:
                    for r in records:
                        all_records.append({
                            "ISO": iso,
                            "Country": name,
                            "YearQuarter": r["date"][:7],
                            "Indicator": r["indicator"],
                            "PriceType": r["price_type"],
                            "Adjustment": r["s_adjustment"],
                            "Transform": r["type_of_transformation"],
                            "Frequency": r["frequency"],
                            "GDP": r["value"],
                            "DataSource": "IMF_QNEA",
                        })
                    print(f"  [OK] {name:<20} ({iso}) {pt}/{sa}: {len(records)} quarters")
                    downloaded = True
            except Exception as e:
                pass
            time.sleep(0.15)

        if not downloaded:
            print(f"  [MISS] {name:<20} ({iso}): IMF QNEA无数据，转由World Bank补充")
            WORLDBANK_BACKFILL.append(iso)

    df = pd.DataFrame(all_records)
    if not df.empty:
        df["YearQuarter"] = pd.PeriodIndex(df["YearQuarter"], freq="Q")
        df = df.sort_values(["Country", "YearQuarter"]).reset_index(drop=True)
    print(f"\n  IMF QNEA下载完成，共 {len(df)} 条季度记录。\n")
    return df


# ========================== Step 2: World Bank补充缺失国家 ==========================
def download_worldbank_gdp():
    """
    从World Bank API获取年度名义GDP（美元），然后做年度→季度→月度双重插值。
    """
    print("=" * 70)
    print("Step 2: 从World Bank WDI补充年度GDP并插值到月度")
    print("=" * 70)

    all_records = []
    for iso in WORLDBANK_BACKFILL:
        name = COUNTRIES[iso]
        url = (
            f"https://api.worldbank.org/v2/country/{iso}/indicator/"
            f"NY.GDP.MKTP.CD?format=json&date=2002:2025&per_page=100"
        )
        try:
            resp = requests.get(url, timeout=30)
            data = resp.json()
            if len(data) <= 1 or not data[1]:
                print(f"  [MISS] {name:<20} ({iso}): World Bank无数据")
                continue

            # 构建年度DataFrame
            annual = pd.DataFrame(data[1])[["date", "value"]].dropna()
            annual["date"] = pd.to_datetime(annual["date"], format="%Y")
            annual = annual.sort_values("date").set_index("date")["value"]

            # 年度→季度插值（每1年分成4个季度）
            quarterly = annual.resample("QE").interpolate(method="linear")

            # 季度→月度插值（每1季度分成3个月）
            monthly = quarterly.resample("MS").interpolate(method="linear")
            monthly = monthly.loc["2002-01-01":"2025-12-01"]

            for date, value in monthly.items():
                all_records.append({
                    "ISO": iso,
                    "Country": name,
                    "YearMonth": date.strftime("%Y-%m"),
                    "Indicator": "NY.GDP.MKTP.CD",
                    "PriceType": "V",
                    "Adjustment": "NSA",
                    "Transform": "USD",
                    "Frequency": "M",
                    "GDP": round(value, 2),
                    "GDP_interp": round(value, 2),
                    "is_interpolated": True,
                    "DataSource": "WorldBank_WDI",
                })

            print(f"  [OK] {name:<20} ({iso}): World Bank年度→月度插值完成 ({len(monthly)} months)")
            time.sleep(0.3)
        except Exception as e:
            print(f"  [ERR] {name:<20} ({iso}): {str(e)[:60]}")

    df = pd.DataFrame(all_records)
    print(f"\n  World Bank补充完成，共 {len(df)} 条月度记录。\n")
    return df


# ========================== Step 3: 季度→月度插值 ==========================
def quarterly_to_monthly(df_q):
    """
    将季度GDP数据插值为月度数据。
    方法：季度值赋给季度首月，缺失月份线性插值。
    """
    print("=" * 70)
    print("Step 3: 季度GDP → 月度线性插值")
    print("=" * 70)

    if df_q.empty:
        return pd.DataFrame()

    # 构建完整月度网格
    meta = df_q[["ISO", "Country"]].drop_duplicates().sort_values("ISO")
    all_dates = pd.date_range("2002-01-01", "2025-12-01", freq="MS")

    grid = pd.MultiIndex.from_product(
        [meta["ISO"].values, all_dates], names=["ISO", "YearMonth"]
    )
    df_m = pd.DataFrame(index=grid).reset_index()
    df_m = df_m.merge(meta, on="ISO", how="left")
    df_m["YearMonth"] = pd.to_datetime(df_m["YearMonth"])

    # 季度数据：将季度首月作为锚点
    df_q["YearMonth"] = df_q["YearQuarter"].dt.to_timestamp()
    df_anchor = df_q[["ISO", "Country", "YearMonth", "GDP", "PriceType", "Adjustment", "DataSource"]].copy()

    # 合并
    df_merged = df_m.merge(df_anchor, on=["ISO", "Country", "YearMonth"], how="left")

    # 分组线性插值
    groups = []
    for iso, g in df_merged.groupby("ISO"):
        g = g.sort_values("YearMonth").copy()
        g["GDP_interp"] = g["GDP"].interpolate(method="linear")
        g["is_interpolated"] = g["GDP"].isna() & g["GDP_interp"].notna()
        # 向前/向后填充静态属性
        for col in ["PriceType", "Adjustment", "DataSource"]:
            if col in g.columns and g[col].notna().any():
                g[col] = g[col].ffill().bfill()
        groups.append(g)

    df_out = pd.concat(groups, ignore_index=True)
    df_out = df_out.sort_values(["Country", "YearMonth"]).reset_index(drop=True)
    df_out["Frequency"] = "M"
    print(f"  插值完成，共 {len(df_out)} 条月度记录。\n")
    return df_out


# ========================== Step 4: 合并与保存 ==========================
def merge_and_save(df_imf_monthly, df_wb_monthly):
    """合并IMF月度插值数据与World Bank补充数据，保存最终CSV。"""
    print("=" * 70)
    print("Step 4: 合并数据并保存CSV")
    print("=" * 70)

    # 标准化列
    cols = ["ISO", "Country", "YearMonth", "Frequency", "PriceType", "Adjustment",
            "GDP", "GDP_interp", "is_interpolated", "DataSource"]

    if not df_imf_monthly.empty:
        df_imf_monthly = df_imf_monthly[[c for c in cols if c in df_imf_monthly.columns]]
    if not df_wb_monthly.empty:
        df_wb_monthly = df_wb_monthly[[c for c in cols if c in df_wb_monthly.columns]]

    df_final = pd.concat([df_imf_monthly, df_wb_monthly], ignore_index=True)
    df_final = df_final.sort_values(["Country", "YearMonth"]).reset_index(drop=True)

    # 格式化
    df_final["YearMonth"] = pd.to_datetime(df_final["YearMonth"]).dt.strftime("%Y-%m")
    df_final["GDP"] = df_final["GDP"].round(2)
    df_final["GDP_interp"] = df_final["GDP_interp"].round(2)

    # 保存
    out_path = os.path.join(OUTPUT_DIR, "IMF_QNEA_季度GDP_25国_月度插值_2002-2025.csv")
    df_final.to_csv(out_path, index=False, encoding="utf-8-sig")
    print(f"  月度插值版已保存: {out_path}")

    # 完整性报告
    print("\n  --- 数据完整性报告 ---")
    for country in sorted(df_final["Country"].unique()):
        sub = df_final[df_final["Country"] == country]
        n_total = len(sub)
        n_interp = sub["is_interpolated"].sum()
        source = sub["DataSource"].iloc[0] if not sub.empty else "N/A"
        status = "OK 完整" if n_interp == 0 else f"WARN 插值 {int(n_interp)} 月"
        print(f"  {country:<20} {n_total:>3}月 | {status:<15} | 来源: {source}")

    print(f"\n  总计: {len(df_final)} 条记录")
    return df_final


# ========================== 主程序 ==========================
if __name__ == "__main__":
    print("\n" + "=" * 70)
    print("IMF QNEA 季度GDP下载与月度插值脚本")
    print("=" * 70 + "\n")

    # Step 1: IMF QNEA
    df_qnea = download_qnea_gdp()

    # 保存原始季度版
    if not df_qnea.empty:
        q_path = os.path.join(OUTPUT_DIR, "IMF_QNEA_季度GDP_25国_原始季度_2002-2025.csv")
        df_qnea.to_csv(q_path, index=False, encoding="utf-8-sig")
        print(f"  原始季度版已保存: {q_path}\n")

    # Step 2: World Bank补充
    df_wb = download_worldbank_gdp()

    # Step 3: IMF季度→月度插值
    df_imf_monthly = quarterly_to_monthly(df_qnea)

    # Step 4: 合并保存
    df_complete = merge_and_save(df_imf_monthly, df_wb)

    print("\n" + "=" * 70)
    print("全部完成！")
    print("=" * 70)
    print(f"\n输出目录: {OUTPUT_DIR}")
    print("建议在你的PPMLHDFE模型中使用 'GDP_interp' 列作为控制变量，")
    print("并取对数 ln(GDP_interp) 以匹配引力模型的弹性解释。")
