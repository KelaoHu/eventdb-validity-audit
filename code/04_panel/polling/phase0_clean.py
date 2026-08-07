# -*- coding: utf-8 -*-
"""Phase 0: Data Cleaning — Polling + Political Scores Matching"""
import pandas as pd, sys, io, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BASE = r'C:\Users\胡克劳\Desktop\311工程数据'
POLLING = os.path.join(BASE, '07_数据库与民调', '中国与各国互相好感度_逐年.csv')
SCORES_DIR = os.path.join(BASE, '02_中间数据_分数与面板', '月度分数_公平覆盖期')
OUT_DIR = os.path.join(BASE, '07_数据库与民调', '01_清洗后')
os.makedirs(OUT_DIR, exist_ok=True)

# ============================================================
# 0.1: Country name standardization
# ============================================================
print("=" * 60)
print("Phase 0.1: Country Name Standardization")
print("=" * 60)

df = pd.read_csv(POLLING, encoding='utf-8-sig')
print(f"Raw polling rows: {len(df)}")
print(f"Unique evaluators (评价方): {df['评价方'].nunique()}")

NAME_MAP = {
    'Britain': 'United Kingdom',
    'Great Britain': 'United Kingdom',
    'US': 'United States',
    '美国': 'United States',
    '澳大利亚': 'Australia',
    '日本': 'Japan',
    'Côte d\'Ivoire': "Cote d'Ivoire",
    'Cote d\'Ivoire': "Cote d'Ivoire",
    'Pakistan refield': 'Pakistan',
    'Palestinian Territories': 'Palestinian territories',
    'São Tomé and Príncipe': 'Sao Tome and Principe',
    'Cape Verde': 'Cabo Verde',
    'Swaziland': 'Eswatini',
}

df['evaluator_std'] = df['评价方'].map(NAME_MAP).fillna(df['评价方'])
print(f"Name mappings applied: {len(NAME_MAP)}")
print(f"Unique evaluators after mapping: {df['evaluator_std'].nunique()}")

# ============================================================
# 0.2: Filter to 25 study countries
# ============================================================
print("\n" + "=" * 60)
print("Phase 0.2: Filter to 25 Study Countries")
print("=" * 60)

STUDY_25 = [
    'Australia', 'Belgium', 'Brazil', 'Canada', 'France', 'Germany',
    'India', 'Indonesia', 'Iran', 'Italy', 'Japan', 'Malaysia', 'Mexico',
    'Netherlands', 'Philippines', 'Russia', 'Saudi Arabia', 'Singapore',
    'South Korea', 'Spain', 'Thailand', 'United Arab Emirates',
    'United Kingdom', 'United States', 'Vietnam'
]

# Filter: evaluator is in 25 countries, direction is X→中国 (exclude 中国→X)
df_25 = df[
    (df['evaluator_std'].isin(STUDY_25)) &
    (~df['方向'].str.startswith('中国→', na=False))
].copy()

print(f"Rows in 25 countries: {len(df_25)}")
print(f"Study countries with data: {df_25['evaluator_std'].nunique()}/25")

# Identify missing countries
has_data = set(df_25['evaluator_std'].unique())
missing = [c for c in STUDY_25 if c not in has_data]
print(f"Missing (0 polling data): {missing}")

# Coverage summary per country
coverage = df_25.groupby('evaluator_std').agg(
    n_obs=('年份', 'count'),
    year_min=('年份', 'min'),
    year_max=('年份', 'max'),
    sources=('数据来源机构', lambda x: ', '.join(sorted(x.unique())))
).reset_index()
coverage.columns = ['country', 'n_obs', 'year_min', 'year_max', 'sources']
coverage = coverage.sort_values('n_obs', ascending=False)

print("\nCoverage summary (sorted by n_obs):")
for _, row in coverage.iterrows():
    flag = ''
    if row['n_obs'] <= 2:
        flag = ' [!] SPARSE'
    print(f"  {row['country']:25s}  {int(row['n_obs']):3d} obs  "
          f"{int(row['year_min'])}-{int(row['year_max'])}  [{row['sources'][:60]}]{flag}")

coverage.to_csv(os.path.join(OUT_DIR, 'polling_coverage_summary.csv'), index=False, encoding='utf-8-sig')
print(f"\nCoverage summary saved to {OUT_DIR}/polling_coverage_summary.csv")

# ============================================================
# 0.3: Match with political scores
# ============================================================
print("\n" + "=" * 60)
print("Phase 0.3: Match with Political Scores")
print("=" * 60)

# Read political scores (GDELT, ICEWS, Phoenix — same format)
def read_scores(fname, db_name):
    path = os.path.join(SCORES_DIR, fname)
    df = pd.read_csv(path)
    # Filter to Aggregated only
    if 'Index_Type' in df.columns:
        df = df[df['Index_Type'] == 'Aggregated'].copy()
    # Standardize columns
    if 'Partner' in df.columns:
        df = df.rename(columns={'Partner': 'country'})
    elif 'Country' in df.columns:
        df = df.rename(columns={'Country': 'country'})
    df = df.rename(columns={'YearMonth': 'month', 'Index_Value': db_name, 'Score': db_name})
    df['month'] = pd.to_datetime(df['month'].astype(str))
    df['year'] = df['month'].dt.year
    # Keep only 2002-2025
    df = df[(df['year'] >= 2002) & (df['year'] <= 2025)]
    # Annual aggregation: mean, std
    annual = df.groupby(['country', 'year'])[db_name].agg(['mean', 'std', 'count']).reset_index()
    annual.columns = ['country', 'year', f'{db_name}_mean', f'{db_name}_std', f'{db_name}_n_months']
    return annual

gdelt_annual = read_scores('gdelt_scores.csv', 'gdelt')
icews_annual = read_scores('icews_scores.csv', 'icews')
phoenix_annual = read_scores('phoenix_scores.csv', 'phoenix')
tsinghua_annual = read_scores('tsinghua_scores.csv', 'tsinghua')

print(f"GDELT annual: {len(gdelt_annual)} rows, {gdelt_annual['country'].nunique()} countries")
print(f"ICEWS annual: {len(icews_annual)} rows, {icews_annual['country'].nunique()} countries")
print(f"Phoenix annual: {len(phoenix_annual)} rows, {phoenix_annual['country'].nunique()} countries")
print(f"Tsinghua annual: {len(tsinghua_annual)} rows, {tsinghua_annual['country'].nunique()} countries")

# Check date ranges
for name, df_s in [('GDELT', gdelt_annual), ('ICEWS', icews_annual),
                    ('Phoenix', phoenix_annual), ('Tsinghua', tsinghua_annual)]:
    print(f"  {name}: {df_s['year'].min()}-{df_s['year'].max()}")

# Merge all political scores
pol_scores = gdelt_annual.copy()
pol_scores = pol_scores.merge(icews_annual, on=['country', 'year'], how='outer')
pol_scores = pol_scores.merge(phoenix_annual, on=['country', 'year'], how='outer')
pol_scores = pol_scores.merge(tsinghua_annual, on=['country', 'year'], how='outer')
print(f"\nMerged political scores: {len(pol_scores)} rows, {pol_scores['country'].nunique()} countries")

# Prepare polling data for merge
df_25_clean = df_25[['evaluator_std', '年份', '指标类型', '好感度数值', '恶感度数值',
                      '有效样本量', '数据来源机构', '调查波次']].copy()
df_25_clean.columns = ['country', 'year', 'indicator_type', 'favorable', 'unfavorable',
                        'n_sample', 'source', 'wave']
df_25_clean['year'] = df_25_clean['year'].astype(int)
df_25_clean['favorable'] = pd.to_numeric(df_25_clean['favorable'], errors='coerce')
df_25_clean['unfavorable'] = pd.to_numeric(df_25_clean['unfavorable'], errors='coerce')
df_25_clean['n_sample'] = pd.to_numeric(df_25_clean['n_sample'], errors='coerce')

# Merge polling with political scores
paired = df_25_clean.merge(pol_scores, on=['country', 'year'], how='left')
n_matched = paired.dropna(subset=['gdelt_mean']).shape[0]
print(f"\nPaired panel: {len(paired)} rows")
print(f"  Rows with GDELT score matched: {n_matched}")
print(f"  Rows with no political score match: {len(paired) - n_matched}")

# Report coverage per database
for db in ['gdelt', 'icews', 'phoenix', 'tsinghua']:
    n = paired[f'{db}_mean'].notna().sum()
    print(f"  {db}: {n}/{len(paired)} matched ({100*n/len(paired):.1f}%)")

# ============================================================
# 0.4: Z-score standardization
# ============================================================
print("\n" + "=" * 60)
print("Phase 0.4: Z-score Standardization")
print("=" * 60)

# Z-score polling by source (separate standardization for each survey instrument)
paired['polling_z'] = paired.groupby('indicator_type')['favorable'].transform(
    lambda x: (x - x.mean()) / x.std()
)
print(f"Z-score by indicator_type ({paired['indicator_type'].nunique()} types):")
for itype, grp in paired.groupby('indicator_type'):
    fav = grp['favorable'].dropna()
    if len(fav) > 0:
        print(f"  {itype[:50]}: n={len(fav)}, mean={fav.mean():.1f}, std={fav.std():.1f}")

# Also create alternative: z-score by source institution
paired['polling_z_by_source'] = paired.groupby('source')['favorable'].transform(
    lambda x: (x - x.mean()) / x.std()
)

# ============================================================
# Save outputs
# ============================================================
print("\n" + "=" * 60)
print("Saving Outputs")
print("=" * 60)

# Main paired panel
paired.to_csv(os.path.join(OUT_DIR, 'paired_panel_annual.csv'), index=False, encoding='utf-8-sig')
print(f"paired_panel_annual.csv: {len(paired)} rows x {len(paired.columns)} cols")

# Generate a README for the output
readme = f"""# Phase 0 清洗结果

## 文件

- `paired_panel_annual.csv`: 民调-政治分数配对面板（主分析用）
- `polling_coverage_summary.csv`: 21国民调覆盖摘要

## 配对面板列说明

| 列 | 说明 |
|----|------|
| country | 论文25国标准名 |
| year | 调查年份 |
| indicator_type | 指标类型（好感度%／温度计／影响力正面%） |
| favorable | 原始好感度数值 |
| unfavorable | 原始恶感度数值 |
| n_sample | 有效样本量 |
| source | 数据来源机构 |
| wave | 调查波次 |
| gdelt_mean/icews_mean/phoenix_mean/tsinghua_mean | 四库年度均值 |
| gdelt_std/icews_std/phoenix_std/tsinghua_std | 四库年度标准差 |
| gdelt_n_months/... | 各库该年有效月数 |
| polling_z | 按指标类型z-score标准化的民意分 |
| polling_z_by_source | 按来源机构z-score标准化的民意分 |

## 处理记录

- 国家名映射: Britain→UK, US→US, 澳大利亚→Australia, 日本→Japan 等
- 排除中国→各国方向（仅58行）
- 缺失4国: Iran, Saudi Arabia, Singapore, UAE（无民调数据）
- 稀疏4国: Belgium(1), Thailand(1), Malaysia(2), Vietnam(2)（建议主回归排除）
- 政治分数来源: 公平覆盖期口径（ICEWS≤2023-04, Phoenix≤2019-03 截断段内重算z-score）
- 生成时间: 2026-07-30
"""
with open(os.path.join(OUT_DIR, 'README.md'), 'w', encoding='utf-8') as f:
    f.write(readme)
print("README.md written")

# ============================================================
# Final summary
# ============================================================
print("\n" + "=" * 60)
print("PHASE 0 COMPLETE — Summary")
print("=" * 60)
print(f"Input polling rows: {len(df)}")
print(f"Filtered to 25 countries: {len(df_25)}")
print(f"Paired panel: {len(paired)} rows")
print(f"Countries with data: {paired['country'].nunique()}")
print(f"Year range (polling): {paired['year'].min()}-{paired['year'].max()}")
print(f"Year range (GDELT): {pol_scores['year'].min()}-{pol_scores['year'].max()}")

# Core analysis sample (exclude sparse: <=2 obs)
core_countries = coverage[coverage['n_obs'] > 2]['country'].tolist()
paired_core = paired[paired['country'].isin(core_countries)]
print(f"\nCore analysis sample (countries with >2 obs): {len(paired_core)} rows, {len(core_countries)} countries")
print(f"Excluded (<=2 obs): {[c for c in coverage[coverage['n_obs']<=2]['country'].tolist()]}")
