# -*- coding: utf-8 -*-
# IMF/BIS EER REER 有效汇率下载与处理脚本 v2.0

import pandas as pd
import numpy as np
import os
import io
import time
import warnings

warnings.filterwarnings("ignore")

# ------------------------------------------------------------------------------
# 配置区域
# ------------------------------------------------------------------------------
OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\经济数据库\IMF"
ER_DATA_PATH = os.path.join(OUTPUT_DIR, "IMF_ER_汇率_25国_月度_2002-2025_学术标准版_含WB标注.csv")
SCRIPT_DIR = r"C:\Users\胡克劳\Desktop\Python代码存放\IMF"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(SCRIPT_DIR, exist_ok=True)

START_YEAR = 2002
END_YEAR = 2025
START_DATE = "2002-01-01"
END_DATE = "2025-12-01"

# 26国ISO-2代码（25伙伴国 + 中国CN）
COUNTRIES_26 = {
    "AU": "Australia",      "BE": "Belgium",        "BR": "Brazil",
    "CA": "Canada",         "CN": "China",          "FR": "France",
    "DE": "Germany",        "IN": "India",          "ID": "Indonesia",
    "IR": "Iran",           "IT": "Italy",          "JP": "Japan",
    "KR": "South Korea",    "MY": "Malaysia",       "MX": "Mexico",
    "NL": "Netherlands",    "PH": "Philippines",    "RU": "Russia",
    "SA": "Saudi Arabia",   "SG": "Singapore",      "ES": "Spain",
    "TH": "Thailand",       "AE": "United Arab Emirates",
    "GB": "United Kingdom", "US": "United States",  "VN": "Vietnam",
}

# BIS应覆盖的国家（除越南外全部尝试）
BIS_AVAILABLE = [iso for iso in COUNTRIES_26.keys() if iso != "VN"]

# 越南需要ER代理
NA_COUNTRIES = ["VN"]

# 伊朗结构性断裂日期
IRAN_BREAKPOINT = "2018-04-01"


# ------------------------------------------------------------------------------
# Step 1: 从BIS SDMX API下载REER数据
# ------------------------------------------------------------------------------
def download_bis_reer():
    """
    通过BIS官方SDMX API逐个下载REER(CPI-based, Broad)数据。
    覆盖26国中除越南外的25国（含中国CN）。
    """
    import requests

    all_records = []
    print("=" * 70)
    print("Step 1: 从BIS SDMX API下载REER数据（25国，含中国CN）")
    print("=" * 70)

    for iso in BIS_AVAILABLE:
        name = COUNTRIES_26[iso]
        url = f"https://stats.bis.org/api/v1/data/BIS,WS_EER,1.0/M.R.B.{iso}?format=csv"
        try:
            response = requests.get(url, timeout=30)
            if response.status_code != 200:
                print(f"  [FAIL] {name:<25} ({iso}) HTTP {response.status_code}")
                continue

            df = pd.read_csv(io.StringIO(response.text))
            for _, row in df.iterrows():
                all_records.append({
                    "ISO": iso,
                    "Country": name,
                    "YearMonth": str(row["TIME_PERIOD"]),
                    "REER_raw": float(row["OBS_VALUE"]),
                    "Source": "BIS",
                })
            print(f"  [OK]   {name:<25} ({iso}) {len(df):>4} 条")
            time.sleep(0.15)
        except Exception as e:
            print(f"  [ERR]  {name:<25} ({iso}) {str(e)[:60]}")

    df = pd.DataFrame(all_records)
    print(f"\n  BIS下载完成，共 {len(df)} 条记录，覆盖 {df['ISO'].nunique()} 个国家。\n")
    return df


# ------------------------------------------------------------------------------
# Step 2: 从IMF EER API补充伊朗数据（BIS无伊朗REER）
# ------------------------------------------------------------------------------
def download_imf_reer_iran():
    """
    通过 world_economic_outlook 包下载伊朗的IMF EER REER数据。
    指标代码：REER_IX_RY2010_ACW_RCPI（CPI-based REER）
    BIS API对伊朗返回404，需用IMF补充。
    """
    print("=" * 70)
    print("Step 2: 从IMF EER API补充伊朗(IR)数据")
    print("=" * 70)

    try:
        from world_economic_outlook import eer
        records = eer(
            isos="IR",
            indicator="REER_IX_RY2010_ACW_RCPI",
            frequency="M",
            start_date=START_DATE,
            end_date=END_DATE,
            use_iso_alpha2=True,
        )
        if not records:
            print("  [FAIL] 未获取到伊朗数据")
            return pd.DataFrame()

        df = pd.DataFrame(records)
        df = df.rename(columns={"iso": "ISO", "date": "YearMonth", "value": "REER_raw"})
        df["Country"] = COUNTRIES_26["IR"]
        df["YearMonth"] = pd.to_datetime(df["YearMonth"]).dt.strftime("%Y-%m")
        df["Source"] = "IMF_EER"
        print(f"  [OK]   Iran (IR) {len(df):>4} 条")
        return df[["ISO", "Country", "YearMonth", "REER_raw", "Source"]]
    except Exception as e:
        print(f"  [ERR]  Iran (IR) {str(e)[:80]}")
        return pd.DataFrame()


# ------------------------------------------------------------------------------
# Step 3: 合并数据并构建完整面板
# ------------------------------------------------------------------------------
def merge_and_build_panel(df_bis, df_imf):
    """
    合并BIS和IMF数据，构建26国完整面板（2002-01 ~ 2025-12）。
    对缺失月份进行线性插值（仅限中间缺失，不清除边界）。
    """
    print("=" * 70)
    print("Step 3: 合并数据并构建完整面板")
    print("=" * 70)

    df = pd.concat([df_bis, df_imf], ignore_index=True)
    df["YearMonth"] = pd.to_datetime(df["YearMonth"])
    print(f"  合并后原始观测: {len(df)} 条")

    # 构建完整网格：26国 × 288个月
    all_dates = pd.date_range(START_DATE, END_DATE, freq="MS")
    grid = pd.MultiIndex.from_product(
        [sorted(COUNTRIES_26.keys()), all_dates],
        names=["ISO", "YearMonth"]
    )
    df_full = pd.DataFrame(index=grid).reset_index()

    iso_to_name = {iso: name for iso, name in COUNTRIES_26.items()}
    df_full["Country"] = df_full["ISO"].map(iso_to_name)

    df_merged = df_full.merge(
        df[["ISO", "YearMonth", "REER_raw", "Source"]],
        on=["ISO", "YearMonth"], how="left"
    )

    # 按国家分组处理
    interpolated = []
    for iso, group in df_merged.groupby("ISO"):
        group = group.sort_values("YearMonth").copy()
        
        if iso in NA_COUNTRIES:
            # 越南：全部标记为NA，后续用ER代理
            group["REER"] = np.nan
            group["is_interpolated"] = False
            group["Source"] = "NA_NotAvailable"
        else:
            # 其他国家：线性插值（中间缺失），保留边界NA
            group["REER"] = group["REER_raw"].interpolate(method="linear")
            group["is_interpolated"] = group["REER_raw"].isna() & group["REER"].notna()
            group["Source"] = group["Source"].fillna("Interpolated")
        
        interpolated.append(group)

    df_result = pd.concat(interpolated, ignore_index=True)
    df_result = df_result.sort_values(["Country", "YearMonth"]).reset_index(drop=True)

    # 统计
    total_interp = df_result["is_interpolated"].sum()
    total_na = df_result["REER"].isna().sum()
    print(f"  面板总观测: {len(df_result)} (26国 × 288月 = 7,488)")
    print(f"  原始观测:   {df_result['REER_raw'].notna().sum()}")
    print(f"  插值填补:   {int(total_interp)} 条")
    print(f"  仍缺失:     {int(total_na)} 条（全部为越南VN）")

    # 各国概况
    print("\n  --- 各国数据覆盖情况 ---")
    for iso in sorted(COUNTRIES_26.keys()):
        sub = df_result[df_result["ISO"] == iso]
        raw_cnt = sub["REER_raw"].notna().sum()
        interp_cnt = sub["is_interpolated"].sum()
        na_cnt = sub["REER"].isna().sum()
        date_min = sub["YearMonth"].min().strftime("%Y-%m")
        date_max = sub["YearMonth"].max().strftime("%Y-%m")
        if na_cnt > 0:
            status = f"[WARN] 缺失 {na_cnt} 条（需ER代理）"
        elif interp_cnt > 0:
            status = f"[OK] 插值 {interp_cnt} 条"
        else:
            status = "[OK] 完整"
        print(f"  {COUNTRIES_26[iso]:<25} {iso} | {raw_cnt:>4}原始 + {interp_cnt:>3}插值 | {date_min}~{date_max} | {status}")

    return df_result


# ------------------------------------------------------------------------------
# Step 4: 为越南生成REER代理（基于名义汇率ER）
# ------------------------------------------------------------------------------
def add_vn_reer_proxy(df):
    """
    用名义汇率ER为越南生成REER代理变量。
    原理：REER ≈ ER × (P_foreign / P_domestic)。当缺乏价格数据时，
    用名义汇率ER作为REER的代理变量是标准做法。
    注意：ER和REER方向相反（ER↑=贬值，REER↑=升值），因此需要取倒数。
    """
    print("\n" + "=" * 70)
    print("Step 4: 为越南(VN)生成REER代理变量")
    print("=" * 70)

    if not os.path.exists(ER_DATA_PATH):
        print(f"  [WARN] ER数据文件不存在: {ER_DATA_PATH}")
        print(f"  [WARN] 无法生成越南REER代理。越南将保持NA。")
        return df

    try:
        er_df = pd.read_csv(ER_DATA_PATH, encoding="utf-8-sig")
        # 处理BOM导致的列名问题
        iso_col = "ISO"
        if "\ufeffISO" in er_df.columns:
            iso_col = "\ufeffISO"
        # 提取越南Period_Average汇率
        vn_er = er_df[(er_df[iso_col] == "VN") & (er_df["Rate_Type"] == "Period_Average")][
            ["YearMonth", "ExchangeRate"]
        ].copy()
        vn_er["YearMonth"] = pd.to_datetime(vn_er["YearMonth"])
        
        # 越南汇率：VND/USD，数值大表示贬值
        # REER_proxy = 1/ER（取倒数使方向与REER一致：升值=数值上升）
        # 然后标准化到2010=100的基期（与BIS REER一致）
        vn_er["REER_proxy_raw"] = 1.0 / vn_er["ExchangeRate"]
        
        # 标准化：以2010年均值为100
        base_2010 = vn_er[(vn_er["YearMonth"] >= "2010-01-01") & (vn_er["YearMonth"] <= "2010-12-31")]["REER_proxy_raw"].mean()
        vn_er["REER_proxy"] = vn_er["REER_proxy_raw"] / base_2010 * 100.0
        
        # 合并到主数据
        vn_merge = vn_er[["YearMonth", "REER_proxy"]].copy()
        df = df.merge(vn_merge, on="YearMonth", how="left")
        
        # 对越南行：用REER_proxy填充REER
        vn_mask = df["ISO"] == "VN"
        df.loc[vn_mask, "REER"] = df.loc[vn_mask, "REER_proxy"]
        df.loc[vn_mask, "Source"] = "ER_Proxy"
        
        proxy_count = df.loc[vn_mask, "REER"].notna().sum()
        print(f"  [OK] 越南REER代理已生成，{proxy_count}/288 条有效")
        print(f"  [INFO] 代理方法：REER_proxy = (1/ER) / base_2010 × 100")
        print(f"  [INFO] 2010年均值基准：{base_2010:.6f}")
        
        # 删除临时列
        df = df.drop(columns=["REER_proxy"])
        
    except Exception as e:
        print(f"  [ERR] 生成越南REER代理失败: {str(e)[:80]}")

    return df


# ------------------------------------------------------------------------------
# Step 5: 生成对数变量、国家去均值、Winsorize
# ------------------------------------------------------------------------------
def generate_derived_variables(df):
    """
    生成衍生变量：
      - ln_REER: 自然对数
      - ln_REER_demean: 国家去均值（消除国家间水平差异）
      - ln_REER_winsorized: 1%/99% Winsorize（处理伊朗极端值）
      - Iran_breakpoint_flag: 伊朗结构性断裂标记
    """
    print("\n" + "=" * 70)
    print("Step 5: 生成衍生变量")
    print("=" * 70)

    df = df.copy()
    df["YearMonth_str"] = df["YearMonth"].dt.strftime("%Y-%m")

    # 5.1 ln_REER
    df["ln_REER"] = np.log(df["REER"])
    print(f"  [OK] ln_REER 已生成")

    # 5.2 ln_REER_demean = ln_REER - mean(ln_REER) by ISO
    # 这是REER进入回归的标准做法，消除国家间水平差异
    df["ln_REER_demean"] = df["ln_REER"] - df.groupby("ISO")["ln_REER"].transform("mean")
    print(f"  [OK] ln_REER_demean 已生成（国家去均值）")

    # 5.3 ln_REER_winsorized（1%/99%截尾）
    # 对每个国家分别Winsorize，保留国家内分布特征
    def winsorize_by_group(x):
        valid = x.dropna()
        if len(valid) == 0:
            return x
        lower = np.percentile(valid, 1)
        upper = np.percentile(valid, 99)
        return x.clip(lower=lower, upper=upper)
    
    df["ln_REER_winsorized"] = df.groupby("ISO")["ln_REER"].transform(winsorize_by_group)
    print(f"  [OK] ln_REER_winsorized 已生成（1%/99% Winsorize，按国家分组）")

    # 5.4 伊朗结构性断裂标记
    df["Iran_breakpoint_flag"] = (
        (df["ISO"] == "IR") & (df["YearMonth"] >= IRAN_BREAKPOINT)
    ).astype(int)
    iran_break_count = df["Iran_breakpoint_flag"].sum()
    print(f"  [OK] Iran_breakpoint_flag 已生成，标记 {iran_break_count} 条（2018-04起）")

    # 5.5 越南代理标记
    df["is_ER_proxy"] = (df["Source"] == "ER_Proxy").astype(int)
    print(f"  [OK] is_ER_proxy 已生成，标记 {df['is_ER_proxy'].sum()} 条")

    return df


# ------------------------------------------------------------------------------
# Step 6: 生成最终输出
# ------------------------------------------------------------------------------
def generate_output(df):
    """
    生成最终CSV文件，包含所有变量和完整注释。
    """
    print("\n" + "=" * 70)
    print("Step 6: 生成最终输出文件")
    print("=" * 70)

    # 最终列顺序
    out = df[[
        "ISO", "Country", "YearMonth_str", "REER_raw", "REER",
        "ln_REER", "ln_REER_demean", "ln_REER_winsorized",
        "is_interpolated", "is_ER_proxy", "Iran_breakpoint_flag", "Source"
    ]].copy()
    out.columns = [
        "ISO", "Country", "YearMonth", "REER_raw", "REER",
        "ln_REER", "ln_REER_demean", "ln_REER_winsorized",
        "is_interpolated", "is_ER_proxy", "Iran_breakpoint_flag", "Source"
    ]

    # 四舍五入
    out["REER"] = out["REER"].round(4)
    out["ln_REER"] = out["ln_REER"].round(6)
    out["ln_REER_demean"] = out["ln_REER_demean"].round(6)
    out["ln_REER_winsorized"] = out["ln_REER_winsorized"].round(6)

    # 保存
    output_path = os.path.join(OUTPUT_DIR, "IMF_EER_REER_26国含中国_月度_2002-2025_学术标准版.csv")
    out.to_csv(output_path, index=False, encoding="utf-8-sig")
    print(f"  [OK] 已保存: {output_path}")
    print(f"       共 {len(out)} 行 × {len(out.columns)} 列")

    # 描述性统计（按变量分组）
    print("\n  --- REER 描述性统计（按国家） ---")
    desc = out[out["REER"].notna()].groupby("Country")["REER"].agg(
        ["count", "mean", "std", "min", "max"]
    ).round(2)
    print(desc.to_string())

    print("\n  --- ln_REER_demean 描述性统计（按国家） ---")
    desc_dm = out[out["ln_REER_demean"].notna()].groupby("Country")["ln_REER_demean"].agg(
        ["count", "mean", "std", "min", "max"]
    ).round(4)
    print(desc_dm.to_string())

    # Source分布
    print("\n  --- Source分布 ---")
    print(out["Source"].value_counts().to_string())

    # 关键诊断
    print("\n  --- 关键诊断 ---")
    print(f"  总观测: {len(out)}")
    print(f"  有效REER: {out['REER'].notna().sum()}")
    print(f"  插值: {out['is_interpolated'].sum()}")
    print(f"  ER代理(越南): {out['is_ER_proxy'].sum()}")
    print(f"  Iran断裂标记: {out['Iran_breakpoint_flag'].sum()}")
    
    # 伊朗对比
    ir_before = out[(out["ISO"] == "IR") & (out["YearMonth"] < "2018-04")]["REER"]
    ir_after = out[(out["ISO"] == "IR") & (out["YearMonth"] >= "2018-04")]["REER"]
    print(f"\n  伊朗REER对比:")
    print(f"    2018前: mean={ir_before.mean():.1f}, std={ir_before.std():.1f}, max={ir_before.max():.1f}")
    print(f"    2018后: mean={ir_after.mean():.1f}, std={ir_after.std():.1f}, max={ir_after.max():.1f}")

    return out


# ------------------------------------------------------------------------------
# 主程序
# ------------------------------------------------------------------------------
if __name__ == "__main__":
    print("\n" + "=" * 70)
    print("IMF/BIS EER REER 有效汇率下载与处理脚本 v2.0")
    print("26国含中国 | 国家去均值 | Winsorize | 越南ER代理")
    print("=" * 70)
    print("\n[重要提示]")
    print("本脚本处理 Real Effective Exchange Rate (REER) 指数。")
    print("单位：Index (基期2010=100)，无量纲，无需换算。")
    print("方向：REER 上升 = 本币实际升值（与ER变量方向相反）。")
    print("关键变量：ln_REER_demean（国家去均值，回归首选）")
    print("=" * 70 + "\n")

    # Step 1: BIS下载（25国+中国）
    df_bis = download_bis_reer()

    # Step 2: IMF补充伊朗
    df_imf = download_imf_reer_iran()

    # Step 3: 合并面板
    df_panel = merge_and_build_panel(df_bis, df_imf)

    # Step 4: 越南ER代理
    df_panel = add_vn_reer_proxy(df_panel)

    # Step 5: 衍生变量
    df_panel = generate_derived_variables(df_panel)

    # Step 6: 输出
    df_final = generate_output(df_panel)

    print("\n" + "=" * 70)
    print("全部完成！")
    print("=" * 70)
    print(f"\n输出文件: {os.path.join(OUTPUT_DIR, 'IMF_EER_REER_26国含中国_月度_2002-2025_学术标准版.csv')}")
    print("\n使用说明：")
    print("  1. 回归控制变量首选：ln_REER_demean（国家去均值，消除水平差异）")
    print("  2. 稳健性检验可用：ln_REER_winsorized（处理伊朗极端值）")
    print("  3. 科研目的3.2：提取ISO=CN的行作为ln_REER_CHN")
    print("  4. 越南REER由ER代理生成，已在Source中标记为ER_Proxy")
    print("  5. 伊朗2018年后数据已标记Iran_breakpoint_flag，可用于子样本分析")
    print("=" * 70)
