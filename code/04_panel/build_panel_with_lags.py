# -*- coding: utf-8 -*-
# PPMLHDFE 数据面板准备脚本

import pandas as pd
import numpy as np
import os
from datetime import datetime

# ============================================================
# 路径配置
# ============================================================
BASE_DIR = os.path.expanduser("~/Desktop/政治经济的冷与热科研")
DATA_ORIG = os.path.join(BASE_DIR, "原数据副本")
DATA_CTRL = os.path.join(BASE_DIR, "经济数据库")
OUTPUT_DIR = os.path.join(BASE_DIR, "PPMLHDFE", "政治关系传导贸易变化尝试")

os.makedirs(OUTPUT_DIR, exist_ok=True)

print("=" * 70)
print("PPMLHDFE 数据面板准备")
print("=" * 70)

# ============================================================
# 1. 贸易数据转换
# ============================================================
print("\n[Step 1] 读取并转换贸易数据...")

df_trade_raw = pd.read_csv(os.path.join(DATA_ORIG, "IMF数据库2002.1-2025.12双边经济数据.csv"))

# 国家名称映射：IMF → 标准名称
name_map = {
    "Russian Federation": "Russia",
    "Korea, Republic of": "South Korea",
    "Netherlands, The": "Netherlands",
    "Iran, Islamic Republic of": "Iran",
}

df_trade_raw["COUNTERPART_COUNTRY"] = df_trade_raw["COUNTERPART_COUNTRY"].replace(name_map)

# 确定月份列（以 "2002-M01" 格式开头），只保留到 2025-12
month_cols = [c for c in df_trade_raw.columns if c.startswith("20") and "-M" in c]
month_cols = [c for c in month_cols if not c.startswith("2026")]
print(f"  发现 {len(month_cols)} 个月份列，时间范围: {month_cols[0]} ~ {month_cols[-1]}")

# 将 wide format 转换为 long format
df_trade_long = df_trade_raw.melt(
    id_vars=["COUNTERPART_COUNTRY", "INDICATOR"],
    value_vars=month_cols,
    var_name="YearMonth_Str",
    value_name="Value"
)

# 解析 YearMonth
df_trade_long["YearMonth"] = pd.to_datetime(df_trade_long["YearMonth_Str"], format="%Y-M%m")

# 区分出口和进口
df_trade_long["Type"] = df_trade_long["INDICATOR"].apply(
    lambda x: "Exports" if "Exports" in x else "Imports"
)

# 按国家和时间聚合
exports = df_trade_long[df_trade_long["Type"] == "Exports"].groupby(
    ["COUNTERPART_COUNTRY", "YearMonth"]
)["Value"].sum().reset_index().rename(columns={"Value": "Trade_Exports"})

imports = df_trade_long[df_trade_long["Type"] == "Imports"].groupby(
    ["COUNTERPART_COUNTRY", "YearMonth"]
)["Value"].sum().reset_index().rename(columns={"Value": "Trade_Imports"})

df_trade = exports.merge(imports, on=["COUNTERPART_COUNTRY", "YearMonth"], how="outer")
df_trade["Trade_Total"] = df_trade["Trade_Exports"].fillna(0) + df_trade["Trade_Imports"].fillna(0)
df_trade = df_trade.rename(columns={"COUNTERPART_COUNTRY": "Country"})

# 处理零值：PPML 要求因变量 > 0
zero_count_total = (df_trade["Trade_Total"] == 0).sum()
zero_count_exp = (df_trade["Trade_Exports"] == 0).sum()
zero_count_imp = (df_trade["Trade_Imports"] == 0).sum()
print(f"  总贸易额零值: {zero_count_total} 个, 出口零值: {zero_count_exp} 个, 进口零值: {zero_count_imp} 个")
print(f"  将零值替换为 0.001 以满足 PPML 要求")

df_trade["Trade_Total"] = df_trade["Trade_Total"].replace(0, 0.001)
df_trade["Trade_Exports"] = df_trade["Trade_Exports"].replace(0, 0.001)
df_trade["Trade_Imports"] = df_trade["Trade_Imports"].replace(0, 0.001)

print(f"  贸易数据行数: {len(df_trade)}, 国家数: {df_trade['Country'].nunique()}")

# ============================================================
# 2. 政治关系数据
# ============================================================
print("\n[Step 2] 读取并转换政治关系数据 (GDELT)...")

df_pol = pd.read_csv(os.path.join(DATA_ORIG, "GDELT_月度几何平均指数_由日到月.csv"))
df_pol["YearMonth"] = pd.to_datetime(df_pol["YearMonth"])

# 将 Index_Type 展开为三列
df_pol_wide = df_pol.pivot_table(
    index=["Partner", "YearMonth"],
    columns="Index_Type",
    values="Index_Value"
).reset_index()

df_pol_wide.columns.name = None
df_pol_wide = df_pol_wide.rename(columns={
    "Partner": "Country",
    "Aggregated": "Pol_Agg",
    "CHN->Partner": "Pol_CHN_Partner",
    "Partner->CHN": "Pol_Partner_CHN"
})

# 确保有三列（如果某列不存在则补零）
for col in ["Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"]:
    if col not in df_pol_wide.columns:
        df_pol_wide[col] = 0.0

print(f"  政治关系数据行数: {len(df_pol_wide)}, 国家数: {df_pol_wide['Country'].nunique()}")

# ============================================================
# 3. 汇率数据
# ============================================================
print("\n[Step 3] 读取汇率数据...")

# 查找汇率文件
imf_dir = os.path.join(DATA_CTRL, "IMF")
er_files = [f for f in os.listdir(imf_dir) if "ER_" in f and "插值" in f and f.endswith(".csv")]
if not er_files:
    # 回退：查找任何包含 ER 的 csv
    er_files = [f for f in os.listdir(imf_dir) if "ER" in f and f.endswith(".csv")]

er_path = os.path.join(imf_dir, er_files[0])
print(f"  使用汇率文件: {er_files[0]}")

df_er = pd.read_csv(er_path)
df_er["YearMonth"] = pd.to_datetime(df_er["YearMonth"])

# 筛选 Period_Average
if "Rate_Type" in df_er.columns:
    df_er = df_er[df_er["Rate_Type"] == "Period_Average"].copy()

# 只保留伙伴国（去掉 China）
df_er = df_er[df_er["Country"] != "China"].copy()

# 重命名列
df_er = df_er.rename(columns={"ExchangeRate": "ER"})
df_er = df_er[["Country", "YearMonth", "ER"]].copy()

print(f"  汇率数据行数: {len(df_er)}, 国家数: {df_er['Country'].nunique()}")

# ============================================================
# 4. GDP 数据
# ============================================================
print("\n[Step 4] 读取 GDP 数据...")

gdp_files = [f for f in os.listdir(imf_dir) if "GDP" in f and "月度插值" in f and f.endswith(".csv")]
if not gdp_files:
    gdp_files = [f for f in os.listdir(imf_dir) if "GDP" in f and f.endswith(".csv")]

gdp_path = os.path.join(imf_dir, gdp_files[0])
print(f"  使用 GDP 文件: {gdp_files[0]}")

df_gdp = pd.read_csv(gdp_path)
df_gdp["YearMonth"] = pd.to_datetime(df_gdp["YearMonth"])

# 使用 GDP_interp 列
if "GDP_interp" in df_gdp.columns:
    df_gdp = df_gdp[["Country", "YearMonth", "GDP_interp"]].copy()
    df_gdp = df_gdp.rename(columns={"GDP_interp": "GDP"})
elif "GDP" in df_gdp.columns:
    df_gdp = df_gdp[["Country", "YearMonth", "GDP"]].copy()
else:
    # 尝试找插值后的列
    interp_cols = [c for c in df_gdp.columns if "interp" in c.lower()]
    if interp_cols:
        df_gdp = df_gdp[["Country", "YearMonth", interp_cols[0]]].copy()
        df_gdp = df_gdp.rename(columns={interp_cols[0]: "GDP"})

# 只保留伙伴国（去掉 China）
df_gdp = df_gdp[df_gdp["Country"] != "China"].copy()

print(f"  GDP 数据行数: {len(df_gdp)}, 国家数: {df_gdp['Country'].nunique()}")

# ============================================================
# 5. FTA 数据
# ============================================================
print("\n[Step 5] 读取 FTA 数据...")

fta_dir = os.path.join(DATA_CTRL, "FTA整理")
fta_files = [f for f in os.listdir(fta_dir) if "月度" in f and f.endswith(".csv")]
fta_path = os.path.join(fta_dir, fta_files[0])
print(f"  使用 FTA 文件: {fta_files[0]}")

df_fta = pd.read_csv(fta_path)
df_fta["YearMonth"] = pd.to_datetime(df_fta["YearMonth"])

# 只保留伙伴国（去掉 China 自身）
df_fta = df_fta[df_fta["Country"] != "China"].copy()
df_fta = df_fta[["Country", "YearMonth", "FTA_Dummy"]].copy()

print(f"  FTA 数据行数: {len(df_fta)}, 国家数: {df_fta['Country'].nunique()}")

# ============================================================
# 6. 合并完整面板
# ============================================================
print("\n[Step 6] 合并完整面板...")

# 以贸易数据为基准（最完整），左连接其他数据
df_panel = df_trade.copy()

# 合并政治关系
df_panel = df_panel.merge(df_pol_wide, on=["Country", "YearMonth"], how="left")

# 合并汇率
df_panel = df_panel.merge(df_er, on=["Country", "YearMonth"], how="left")

# 合并 GDP
df_panel = df_panel.merge(df_gdp, on=["Country", "YearMonth"], how="left")

# 合并 FTA
df_panel = df_panel.merge(df_fta, on=["Country", "YearMonth"], how="left")

# FTA 缺失值填 0
df_panel["FTA_Dummy"] = df_panel["FTA_Dummy"].fillna(0).astype(int)

# 检查缺失值
print(f"\n  合并后行数: {len(df_panel)}")
print(f"  国家数: {df_panel['Country'].nunique()}, 月份数: {df_panel['YearMonth'].nunique()}")
print(f"\n  各列缺失值统计:")
for col in df_panel.columns:
    na_count = df_panel[col].isna().sum()
    # na_count 可能是标量或 Series，统一处理
    if hasattr(na_count, 'item'):
        na_count = na_count.item() if na_count.size == 1 else na_count.sum()
    na_count = int(na_count)
    if na_count > 0:
        print(f"    {col}: {na_count} 个缺失 ({na_count/len(df_panel)*100:.1f}%)")

# ============================================================
# 7. 添加 ISO 代码和国家标识
# ============================================================
print("\n[Step 7] 添加 ISO 代码...")

country_iso_map = {
    "Australia": "AU", "Belgium": "BE", "Brazil": "BR", "Canada": "CA",
    "France": "FR", "Germany": "DE", "India": "IN", "Indonesia": "ID",
    "Iran": "IR", "Italy": "IT", "Japan": "JP", "Malaysia": "MY",
    "Mexico": "MX", "Netherlands": "NL", "Philippines": "PH", "Russia": "RU",
    "Saudi Arabia": "SA", "Singapore": "SG", "South Korea": "KR",
    "Spain": "ES", "Thailand": "TH", "United Arab Emirates": "AE",
    "United Kingdom": "GB", "United States": "US", "Vietnam": "VN"
}

df_panel["ISO"] = df_panel["Country"].map(country_iso_map)

# ============================================================
# 8. 生成滞后变量 L1-L6
# ============================================================
print("\n[Step 8] 生成政治关系滞后变量 L1-L6...")

df_panel = df_panel.sort_values(["Country", "YearMonth"]).reset_index(drop=True)

pol_cols = ["Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"]

for col in pol_cols:
    for lag in range(1, 7):
        df_panel[f"{col}_L{lag}"] = df_panel.groupby("Country")[col].shift(lag)

# 检查滞后变量缺失值
for col in pol_cols:
    for lag in range(1, 7):
        lag_col = f"{col}_L{lag}"
        na_count = df_panel[lag_col].isna().sum()
        if na_count > 0:
            print(f"  {lag_col}: {na_count} 个缺失（前 {lag} 个月无滞后值，正常）")

# ============================================================
# 9. 添加时间趋势和窗口标识
# ============================================================
print("\n[Step 9] 生成时间趋势和滚动窗口标识...")

# 时间趋势（1-288）
df_panel["Trend"] = df_panel.groupby("Country")["YearMonth"].rank(method="dense").astype(int)

# 滚动窗口标识（60个月窗口，12个月滑动）
window_size = 60
step = 12

start_date = df_panel["YearMonth"].min()
end_date = df_panel["YearMonth"].max()

window_id = 0
window_labels = []
current_start = start_date

while current_start + pd.DateOffset(months=window_size-1) <= end_date:
    window_end = current_start + pd.DateOffset(months=window_size-1)
    window_labels.append({
        "Window_ID": window_id,
        "Window_Start": current_start,
        "Window_End": window_end,
        "Window_Label": f"{current_start.strftime('%Y%m')}-{window_end.strftime('%Y%m')}"
    })
    current_start = current_start + pd.DateOffset(months=step)
    window_id += 1

df_windows = pd.DataFrame(window_labels)
print(f"  生成 {len(df_windows)} 个滚动窗口（宽度 {window_size} 月，步长 {step} 月）")
for _, w in df_windows.iterrows():
    print(f"    Window {w['Window_ID']:2d}: {w['Window_Label']}")

# 为每个观测值标记所属窗口（一个观测可能属于多个窗口）
# 采用更简单的方式：在 R 中根据 YearMonth 过滤窗口
# 这里只输出窗口定义表

# ============================================================
# 10. 对数变换
# ============================================================
print("\n[Step 10] 对控制变量取对数...")

# 汇率取对数（local currency / USD，所以升值=数值下降，贬值=数值上升）
df_panel["ln_ER"] = np.log(df_panel["ER"])
# GDP 取对数
df_panel["ln_GDP"] = np.log(df_panel["GDP"])

# ============================================================
# 11. 最终清理与输出
# ============================================================
print("\n[Step 11] 最终数据清理...")

# 按国家和时间排序
df_panel = df_panel.sort_values(["Country", "YearMonth"]).reset_index(drop=True)

# 删除完全缺失政治关系数据的行（主要是开始几个月滞后值缺失）
# 保留：只要 Pol_Agg 不是全空即可
required_cols = ["Pol_Agg", "ln_ER", "ln_GDP", "FTA_Dummy"]
initial_rows = len(df_panel)
df_panel = df_panel.dropna(subset=[c for c in required_cols if c in df_panel.columns])
final_rows = len(df_panel)
print(f"  删除缺失值后: {initial_rows} → {final_rows} 行")

# 输出列顺序
cols_order = [
    "ISO", "Country", "YearMonth", "Trend",
    "Trade_Total", "Trade_Exports", "Trade_Imports",
    "Pol_Agg", "Pol_Agg_L1", "Pol_Agg_L2", "Pol_Agg_L3", "Pol_Agg_L4", "Pol_Agg_L5", "Pol_Agg_L6",
    "Pol_CHN_Partner", "Pol_CHN_Partner_L1", "Pol_CHN_Partner_L2", "Pol_CHN_Partner_L3",
    "Pol_CHN_Partner_L4", "Pol_CHN_Partner_L5", "Pol_CHN_Partner_L6",
    "Pol_Partner_CHN", "Pol_Partner_CHN_L1", "Pol_Partner_CHN_L2", "Pol_Partner_CHN_L3",
    "Pol_Partner_CHN_L4", "Pol_Partner_CHN_L5", "Pol_Partner_CHN_L6",
    "ln_ER", "ln_GDP", "FTA_Dummy"
]

# 确保所有列都存在
df_panel = df_panel[[c for c in cols_order if c in df_panel.columns]]

# 输出 CSV
output_csv = os.path.join(OUTPUT_DIR, "PPMLHDFE_Panel_L0L6.csv")
df_panel.to_csv(output_csv, index=False, encoding="utf-8-sig")
print(f"\n[OK] 面板数据已保存: {output_csv}")
print(f"     形状: {df_panel.shape}")

# 同时输出窗口定义表
windows_csv = os.path.join(OUTPUT_DIR, "Rolling_Windows_Definition.csv")
df_windows.to_csv(windows_csv, index=False, encoding="utf-8-sig")
print(f"[OK] 窗口定义表已保存: {windows_csv}")

# 输出数据摘要
print("\n" + "=" * 70)
print("数据摘要")
print("=" * 70)
print(f"观测值总数: {len(df_panel)}")
print(f"国家数: {df_panel['Country'].nunique()}")
print(f"月份范围: {df_panel['YearMonth'].min().strftime('%Y-%m')} ~ {df_panel['YearMonth'].max().strftime('%Y-%m')}")
print(f"\n各贸易变量统计:")
for col in ["Trade_Total", "Trade_Exports", "Trade_Imports"]:
    print(f"  {col}: 均值={df_panel[col].mean():.2f}, 中位数={df_panel[col].median():.2f}, min={df_panel[col].min():.4f}, max={df_panel[col].max():.2f}")

print(f"\n各政治指数统计:")
for col in ["Pol_Agg", "Pol_CHN_Partner", "Pol_Partner_CHN"]:
    print(f"  {col}: 均值={df_panel[col].mean():.3f}, std={df_panel[col].std():.3f}, min={df_panel[col].min():.3f}, max={df_panel[col].max():.3f}")

print(f"\n控制变量统计:")
for col in ["ln_ER", "ln_GDP", "FTA_Dummy"]:
    if col == "FTA_Dummy":
        print(f"  {col}: 均值={df_panel[col].mean():.3f} (即 {df_panel[col].sum()} 个月有 FTA)")
    else:
        print(f"  {col}: 均值={df_panel[col].mean():.3f}, std={df_panel[col].std():.3f}")

print("\n" + "=" * 70)
print("数据准备完成，请运行 R 脚本进行 PPMLHDFE 估计")
print("=" * 70)
