#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 三库五种算法综合分析（由日到月）- 优化版

import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
from scipy import stats
import warnings
warnings.filterwarnings('ignore')

# ==================== 配置区域 ====================
class Config:
    GDELT_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\GDELT2002_25国严格双边事件_20260414_213010.csv"
    ICEWS_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\ICEWS_中国与25国双边政治事件_2002-01-01_to_2023-04-10.csv"
    PHOENIX_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\Phoenix 数据集合\下载数据源DOI-10-13012-b2idb-0647142_v3"
    OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\三个数据库算法综合分析"
    START_DATE = "2002-01-01"
    END_DATE   = "2019-12-31"
    SHIFT_CONSTANT = 11
    ABS_LAMBDA = 10.0
    EPSILON = 1e-10
    
    TARGET_COUNTRIES = [
        "Japan", "United States", "South Korea", "Germany", "Malaysia",
        "Singapore", "Russia", "United Kingdom", "Netherlands", "Australia",
        "Italy", "Thailand", "France", "Indonesia", "Canada",
        "Philippines", "Saudi Arabia", "India", "Belgium", "Brazil",
        "Mexico", "United Arab Emirates", "Iran", "Spain", "Vietnam"
    ]
    INDEX_TYPES = ["Aggregated", "CHN->Partner", "Partner->CHN"]
    COUNTRY_CODE_TO_NAME = {
        "JPN": "Japan", "USA": "United States", "KOR": "South Korea",
        "DEU": "Germany", "MYS": "Malaysia", "SGP": "Singapore",
        "RUS": "Russia", "GBR": "United Kingdom", "NLD": "Netherlands",
        "AUS": "Australia", "ITA": "Italy", "THA": "Thailand",
        "FRA": "France", "IDN": "Indonesia", "CAN": "Canada",
        "PHL": "Philippines", "SAU": "Saudi Arabia", "IND": "India",
        "BEL": "Belgium", "BRA": "Brazil", "MEX": "Mexico",
        "ARE": "United Arab Emirates", "UAE": "United Arab Emirates",
        "IRN": "Iran", "ESP": "Spain", "VNM": "Vietnam"
    }


# ==================== 数据加载 ====================
class DataLoader:
    @staticmethod
    def load_gdelt(path: str) -> pd.DataFrame:
        print(f"[1/3] 加载 GDELT...", end=" ")
        df = pd.read_csv(path, encoding='utf-8-sig', low_memory=False)
        df['EventDate'] = pd.to_datetime(df['EventDate'], errors='coerce')
        df = df[(df['EventDate'] >= Config.START_DATE) & (df['EventDate'] <= Config.END_DATE)].copy()
        df['Score'] = pd.to_numeric(df['GoldsteinScale'], errors='coerce')
        df['Direction'] = df['Direction'].str.strip()
        df['Partner'] = df.apply(DataLoader._extract_partner_gdelt, axis=1)
        df = df[['EventDate', 'Partner', 'Direction', 'Score']].dropna()
        df = df[df['Partner'].isin(Config.TARGET_COUNTRIES)].copy()
        print(f"{df.shape[0]:,} 条 (过滤后)")
        return df
    
    @staticmethod
    def load_icews(path: str) -> pd.DataFrame:
        print(f"[2/3] 加载 ICEWS...", end=" ")
        df = pd.read_csv(path, encoding='utf-8-sig', low_memory=False)
        df['EventDate'] = pd.to_datetime(df['Event Date'], errors='coerce')
        df = df[(df['EventDate'] >= Config.START_DATE) & (df['EventDate'] <= Config.END_DATE)].copy()
        df['Score'] = pd.to_numeric(df['Intensity'], errors='coerce')
        df['Direction'] = df.apply(DataLoader._infer_icews_direction, axis=1)
        df['Partner'] = df.apply(DataLoader._extract_partner_icews, axis=1)
        df = df[['EventDate', 'Partner', 'Direction', 'Score']].dropna()
        df = df[df['Partner'].isin(Config.TARGET_COUNTRIES)].copy()
        print(f"{df.shape[0]:,} 条 (过滤后)")
        return df
    
    @staticmethod
    def load_phoenix(phoenix_dir: str) -> pd.DataFrame:
        print(f"[3/3] 加载 Phoenix...", end=" ")
        nyt = pd.read_csv(f"{phoenix_dir}/PhoenixBLN-NYT_1980-2018.csv", encoding='utf-8-sig', low_memory=False)
        swb = pd.read_csv(f"{phoenix_dir}/PhoenixBLN-SWB_1979-2019.csv", encoding='utf-8-sig', low_memory=False)
        swb.columns = [c.replace('placename','placeName').replace('statename','stateName').replace('countryname','countryName') for c in swb.columns]
        df = pd.concat([nyt, swb], ignore_index=True)
        df['EventDate'] = pd.to_datetime(df['story_date'], format='%m/%d/%Y', errors='coerce')
        df = df[(df['EventDate'] >= Config.START_DATE) & (df['EventDate'] <= Config.END_DATE)].copy()
        df['Score'] = pd.to_numeric(df['goldstein'], errors='coerce')
        df['Direction'] = df.apply(DataLoader._infer_phoenix_direction, axis=1)
        df['Partner'] = df.apply(DataLoader._extract_partner_phoenix, axis=1)
        df = df[['EventDate', 'Partner', 'Direction', 'Score']].dropna()
        df = df[df['Partner'].isin(Config.TARGET_COUNTRIES)].copy()
        print(f"{df.shape[0]:,} 条 (过滤后)")
        return df
    
    @staticmethod
    def _extract_partner_gdelt(row) -> str:
        d = str(row.get('Direction','')).strip()
        if d == "CHN->Partner":
            code = str(row.get('Actor2CountryCode','')).strip()
            return Config.COUNTRY_CODE_TO_NAME.get(code, code)
        elif d == "Partner->CHN":
            code = str(row.get('Actor1CountryCode','')).strip()
            return Config.COUNTRY_CODE_TO_NAME.get(code, code)
        return ""
    
    @staticmethod
    def _infer_icews_direction(row) -> str:
        for col in row.index:
            if 'direction' in str(col).lower():
                d = str(row[col])
                if 'China -> ' in d: return "CHN->Partner"
                if ' -> China' in d: return "Partner->CHN"
        src = str(row.get('Source Country',''))
        tgt = str(row.get('Target Country',''))
        if 'China' in src or 'china' in src.lower(): return "CHN->Partner"
        if 'China' in tgt or 'china' in tgt.lower(): return "Partner->CHN"
        return ""
    
    @staticmethod
    def _extract_partner_icews(row) -> str:
        for col in row.index:
            if 'direction' in str(col).lower():
                d = str(row[col])
                if 'China -> ' in d: return d.split('China -> ')[1].strip()
                if ' -> China' in d: return d.split(' -> China')[0].strip()
        src = str(row.get('Source Country',''))
        tgt = str(row.get('Target Country',''))
        if 'China' in src or 'china' in src.lower(): return tgt
        if 'China' in tgt or 'china' in tgt.lower(): return src
        return ""
    
    @staticmethod
    def _infer_phoenix_direction(row) -> str:
        src = str(row.get('source_root','')).strip()
        tgt = str(row.get('target_root','')).strip()
        if src == 'CHN': return "CHN->Partner"
        if tgt == 'CHN': return "Partner->CHN"
        return ""
    
    @staticmethod
    def _extract_partner_phoenix(row) -> str:
        src = str(row.get('source_root','')).strip()
        tgt = str(row.get('target_root','')).strip()
        if src == 'CHN' and tgt in Config.COUNTRY_CODE_TO_NAME:
            return Config.COUNTRY_CODE_TO_NAME[tgt]
        if tgt == 'CHN' and src in Config.COUNTRY_CODE_TO_NAME:
            return Config.COUNTRY_CODE_TO_NAME[src]
        if src == 'CHN': return tgt
        if tgt == 'CHN': return src
        return ""


# ==================== 五种算法（高效向量化版）====================
class Algorithms:
    
    @staticmethod
    def _prepare(df: pd.DataFrame) -> pd.DataFrame:
        """通用预处理：添加Date和YearMonth列"""
        df = df.copy()
        df['Date'] = df['EventDate'].dt.date
        df['YearMonth'] = df['EventDate'].dt.to_period('M').astype(str)
        return df
    
    @staticmethod
    def arithmetic_mean(df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        if df.empty: return pd.DataFrame()
        df = Algorithms._prepare(df)
        # 第一步：每日算术平均（方向级别）
        daily_dir = df.groupby(['Partner','Direction','Date','YearMonth'])['Score'].mean().reset_index()
        daily_dir.columns = ['Partner','Direction','Date','YearMonth','DailyScore']
        # 第一步：每日算术平均（Aggregated级别）
        daily_agg = df.groupby(['Partner','Date','YearMonth'])['Score'].mean().reset_index()
        daily_agg.columns = ['Partner','Date','YearMonth','DailyScore']
        daily_agg['Direction'] = 'Aggregated'
        daily_agg = daily_agg[['Partner','Direction','Date','YearMonth','DailyScore']]
        daily = pd.concat([daily_dir, daily_agg], ignore_index=True)
        # 第二步：月度算术平均（基于每日平均）
        monthly = daily.groupby(['Partner','Direction','YearMonth'])['DailyScore'].mean().reset_index()
        monthly.columns = ['Partner','Index_Type','YearMonth','Index_Value']
        return monthly
    
    @staticmethod
    def geometric_mean(df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        if df.empty: return pd.DataFrame()
        df = Algorithms._prepare(df)
        
        def _geo_mean(values):
            s = values + Config.SHIFT_CONSTANT
            if (s > 0).all():
                return np.exp(np.log(s).mean()) - Config.SHIFT_CONSTANT
            return np.nan
        
        # 每日几何平均
        daily_dir = df.groupby(['Partner','Direction','Date','YearMonth'])['Score'].apply(_geo_mean).reset_index()
        daily_dir.columns = ['Partner','Direction','Date','YearMonth','DailyScore']
        daily_agg = df.groupby(['Partner','Date','YearMonth'])['Score'].apply(_geo_mean).reset_index()
        daily_agg.columns = ['Partner','Date','YearMonth','DailyScore']
        daily_agg['Direction'] = 'Aggregated'
        daily_agg = daily_agg[['Partner','Direction','Date','YearMonth','DailyScore']]
        daily = pd.concat([daily_dir, daily_agg], ignore_index=True).dropna()
        
        # 月度算术平均（基于每日几何平均）
        monthly = daily.groupby(['Partner','Direction','YearMonth'])['DailyScore'].mean().reset_index()
        monthly.columns = ['Partner','Index_Type','YearMonth','Index_Value']
        return monthly
    
    @staticmethod
    def median_monthly(df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        if df.empty: return pd.DataFrame()
        df = Algorithms._prepare(df)
        # 每日算术平均
        daily = df.groupby(['Partner','Direction','Date','YearMonth'])['Score'].mean().reset_index()
        daily.columns = ['Partner','Direction','Date','YearMonth','DailyScore']
        # 月度中位数
        dir_monthly = daily.groupby(['Partner','Direction','YearMonth'])['DailyScore'].median().reset_index()
        dir_monthly.columns = ['Partner','Index_Type','YearMonth','Index_Value']
        # Aggregated
        agg_daily = df.groupby(['Partner','Date','YearMonth'])['Score'].mean().reset_index()
        agg_daily.columns = ['Partner','Date','YearMonth','DailyScore']
        agg_monthly = agg_daily.groupby(['Partner','YearMonth'])['DailyScore'].median().reset_index()
        agg_monthly.columns = ['Partner','YearMonth','Index_Value']
        agg_monthly['Index_Type'] = 'Aggregated'
        agg_monthly = agg_monthly[['Partner','Index_Type','YearMonth','Index_Value']]
        return pd.concat([dir_monthly, agg_monthly], ignore_index=True)
    
    @staticmethod
    def quadratic_mean(df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        if df.empty: return pd.DataFrame()
        df = Algorithms._prepare(df)
        
        def _sqm(values):
            v = values.values[~np.isnan(values.values)]
            if len(v) == 0: return np.nan
            ms = np.mean(v**2)
            return np.sign(np.mean(v)) * np.sqrt(ms) if ms > 0 else 0.0
        
        # 每日SQM
        daily_dir = df.groupby(['Partner','Direction','Date','YearMonth'])['Score'].apply(_sqm).reset_index()
        daily_dir.columns = ['Partner','Direction','Date','YearMonth','DailyScore']
        daily_agg = df.groupby(['Partner','Date','YearMonth'])['Score'].apply(_sqm).reset_index()
        daily_agg.columns = ['Partner','Date','YearMonth','DailyScore']
        daily_agg['Direction'] = 'Aggregated'
        daily_agg = daily_agg[['Partner','Direction','Date','YearMonth','DailyScore']]
        daily = pd.concat([daily_dir, daily_agg], ignore_index=True).dropna()
        
        # 事件计数用于加权（方向级别 + Aggregated级别）
        df_count_dir = df.groupby(['Partner','Direction','Date','YearMonth']).size().reset_index(name='EventCount')
        df_count_agg = df.groupby(['Partner','Date','YearMonth']).size().reset_index(name='EventCount')
        df_count_agg['Direction'] = 'Aggregated'
        df_count = pd.concat([df_count_dir, df_count_agg], ignore_index=True)
        daily = daily.merge(df_count, on=['Partner','Direction','Date','YearMonth'], how='left')
        daily['EventCount'] = daily['EventCount'].fillna(1)
        
        # 月度加权SQM
        def _weighted_sqm(group):
            w = group['EventCount'].values
            s = group['DailyScore'].values
            w = w / w.sum()
            wm = np.sum(w * s)
            wmsq = np.sum(w * (s**2))
            return np.sign(wm) * np.sqrt(wmsq) if wmsq > 0 else 0.0
        
        monthly = daily.groupby(['Partner','Direction','YearMonth']).apply(_weighted_sqm).reset_index()
        monthly.columns = ['Partner','Index_Type','YearMonth','Index_Value']
        return monthly
    
    @staticmethod
    def abs_value_weighted(df: pd.DataFrame, dataset_name: str, lambda_val: float = Config.ABS_LAMBDA) -> pd.DataFrame:
        if df.empty: return pd.DataFrame()
        df = Algorithms._prepare(df)
        
        def _weighted_score(scores):
            scores = scores.values
            weights = 1 + lambda_val * np.abs(scores) / 10
            ws = np.sum(weights * scores)
            ww = np.sum(weights)
            return ws / ww if ww > 0 else np.nan
        
        # 每日加权分数
        daily_dir = df.groupby(['Partner','Direction','Date','YearMonth'])['Score'].apply(_weighted_score).reset_index()
        daily_dir.columns = ['Partner','Direction','Date','YearMonth','DailyScore']
        daily_agg = df.groupby(['Partner','Date','YearMonth'])['Score'].apply(_weighted_score).reset_index()
        daily_agg.columns = ['Partner','Date','YearMonth','DailyScore']
        daily_agg['Direction'] = 'Aggregated'
        daily_agg = daily_agg[['Partner','Direction','Date','YearMonth','DailyScore']]
        daily = pd.concat([daily_dir, daily_agg], ignore_index=True).dropna()
        
        # 月度算术平均
        monthly = daily.groupby(['Partner','Direction','YearMonth'])['DailyScore'].mean().reset_index()
        monthly.columns = ['Partner','Index_Type','YearMonth','Index_Value']
        return monthly


# ==================== 插值与完整时间序列 ====================
class Interpolation:
    
    @staticmethod
    def _linear_interpolation(series: pd.Series) -> pd.Series:
        if series.isna().all(): return series
        temp = series.copy()
        temp.index = pd.to_datetime(temp.index, format='%Y-%m')
        interp = temp.interpolate(method='linear')
        interp.index = interp.index.strftime('%Y-%m')
        return interp
    
    @staticmethod
    def _log_space_interpolation(series: pd.Series) -> pd.Series:
        if series.isna().all(): return series
        temp = series.copy()
        temp.index = pd.to_datetime(temp.index, format='%Y-%m')
        shifted = temp + Config.SHIFT_CONSTANT
        log_ts = shifted.apply(lambda x: np.log(x) if x > 0 else np.nan)
        log_interp = log_ts.interpolate(method='linear')
        shifted_interp = np.exp(log_interp)
        result = shifted_interp - Config.SHIFT_CONSTANT
        result.index = result.index.strftime('%Y-%m')
        return result
    
    @staticmethod
    def create_complete_time_series(monthly_df: pd.DataFrame, use_log_space: bool = False) -> pd.DataFrame:
        if monthly_df.empty: return pd.DataFrame()
        dates = pd.period_range(start=Config.START_DATE, end=Config.END_DATE, freq='M')
        all_months = [str(p) for p in dates]
        complete = []
        for (p, idx), sub in monthly_df.groupby(['Partner', 'Index_Type']):
            ts = pd.Series(index=all_months, dtype=float)
            for _, row in sub.iterrows():
                ts[row['YearMonth']] = row['Index_Value']
            ts = Interpolation._log_space_interpolation(ts) if use_log_space else Interpolation._linear_interpolation(ts)
            for month, val in ts.items():
                complete.append({'Partner': p, 'Index_Type': idx, 'YearMonth': month, 'Index_Value': val})
        return pd.DataFrame(complete)


# ==================== 相关性分析 ====================
class CorrelationAnalyzer:
    
    @staticmethod
    def analyze(gdelt_df: pd.DataFrame, other_df: pd.DataFrame, other_name: str, algo_name: str) -> pd.DataFrame:
        results = []
        for partner in Config.TARGET_COUNTRIES:
            for idx_type in Config.INDEX_TYPES:
                g = gdelt_df[(gdelt_df['Partner']==partner) & (gdelt_df['Index_Type']==idx_type)].set_index('YearMonth')['Index_Value']
                o = other_df[(other_df['Partner']==partner) & (other_df['Index_Type']==idx_type)].set_index('YearMonth')['Index_Value']
                common = g.index.intersection(o.index)
                if len(common) < 2: continue
                g_aligned = g.loc[common].dropna()
                o_aligned = o.loc[common].dropna()
                common2 = g_aligned.index.intersection(o_aligned.index)
                if len(common2) < 2: continue
                pr, pp = stats.pearsonr(g_aligned.loc[common2], o_aligned.loc[common2])
                sr, sp = stats.spearmanr(g_aligned.loc[common2], o_aligned.loc[common2])
                results.append({
                    'Partner': partner, 'Index_Type': idx_type, 'Algorithm': algo_name,
                    'Comparison': f'{other_name}_vs_GDELT', 'N': len(common2),
                    'Pearson_r': pr, 'Pearson_p': pp, 'Spearman_r': sr, 'Spearman_p': sp
                })
        return pd.DataFrame(results)
    
    @staticmethod
    def summarize(detailed_df: pd.DataFrame) -> pd.DataFrame:
        if detailed_df.empty: return pd.DataFrame()
        summary = detailed_df.groupby(['Algorithm', 'Index_Type']).agg(
            N_Partners=('Partner','count'),
            Pearson_Median=('Pearson_r','median'), Pearson_Mean=('Pearson_r','mean'), Pearson_SD=('Pearson_r','std'),
            Spearman_Median=('Spearman_r','median'), Spearman_Mean=('Spearman_r','mean'), Spearman_SD=('Spearman_r','std')
        ).reset_index()
        sig_p = detailed_df.groupby(['Algorithm','Index_Type']).apply(lambda x: (x['Pearson_p']<0.05).sum()/len(x)*100 if len(x)>0 else 0).reset_index(name='Pearson_SigPct')
        sig_s = detailed_df.groupby(['Algorithm','Index_Type']).apply(lambda x: (x['Spearman_p']<0.05).sum()/len(x)*100 if len(x)>0 else 0).reset_index(name='Spearman_SigPct')
        summary = summary.merge(sig_p, on=['Algorithm','Index_Type']).merge(sig_s, on=['Algorithm','Index_Type'])
        return summary


# ==================== 主程序 ====================
def main():
    print("=" * 80)
    print("三库五种算法综合分析（由日到月）- 优化版")
    print(f"时间窗口: {Config.START_DATE} 至 {Config.END_DATE}")
    print("=" * 80)
    
    output_dir = Path(Config.OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. 加载
    gdelt_raw = DataLoader.load_gdelt(Config.GDELT_PATH)
    icews_raw = DataLoader.load_icews(Config.ICEWS_PATH)
    phoenix_raw = DataLoader.load_phoenix(Config.PHOENIX_DIR)
    datasets = {'GDELT': gdelt_raw, 'ICEWS': icews_raw, 'Phoenix': phoenix_raw}
    
    algo_map = {
        'Arithmetic Mean': (Algorithms.arithmetic_mean, False),
        'Geometric Mean':  (Algorithms.geometric_mean, True),
        'Median Monthly':  (Algorithms.median_monthly, False),
        'Quadratic Mean (SQM)': (Algorithms.quadratic_mean, False),
        'Abs-Value Weighted': (Algorithms.abs_value_weighted, False),
    }
    
    all_indices = {}
    
    # 2. 计算月度指数
    for db_name, db_df in datasets.items():
        print(f"\n--- 处理 {db_name} ---")
        for algo_name, (algo_func, use_log) in algo_map.items():
            print(f"  → {algo_name}...", end=" ")
            monthly = algo_func(db_df, db_name)
            if monthly.empty:
                print("空")
                continue
            complete = Interpolation.create_complete_time_series(monthly, use_log_space=use_log)
            all_indices[(db_name, algo_name)] = complete
            fname = f"{db_name}_{algo_name.replace(' ','_').replace('(','').replace(')','')}_月度指数_2002-2019.csv"
            complete.to_csv(output_dir / fname, index=False, encoding='utf-8-sig')
            print(f"OK ({len(complete)}行)")
    
    # 3. 合并每种数据库的五种算法
    print(f"\n--- 合并汇总 ---")
    for db_name in datasets.keys():
        merged = []
        for algo_name in algo_map.keys():
            key = (db_name, algo_name)
            if key in all_indices:
                df = all_indices[key].copy()
                df['Algorithm'] = algo_name
                merged.append(df)
        if merged:
            mdf = pd.concat(merged, ignore_index=True)
            mdf = mdf[['Partner','Index_Type','YearMonth','Algorithm','Index_Value']]
            mdf.to_csv(output_dir / f"{db_name}_五种算法_月度指数_汇总_2002-2019.csv", index=False, encoding='utf-8-sig')
            print(f"  {db_name}_五种算法_月度指数_汇总_2002-2019.csv")
    
    # 4. 跨库相关性
    print(f"\n--- 跨库相关性分析 ---")
    gdelt_indices = {algo: all_indices.get(('GDELT',algo)) for algo in algo_map.keys()}
    icews_all, phoenix_all = [], []
    for algo_name in algo_map.keys():
        g, i, p = gdelt_indices.get(algo_name), all_indices.get(('ICEWS',algo_name)), all_indices.get(('Phoenix',algo_name))
        if g is not None and i is not None:
            icews_all.append(CorrelationAnalyzer.analyze(g, i, 'ICEWS', algo_name))
        if g is not None and p is not None:
            phoenix_all.append(CorrelationAnalyzer.analyze(g, p, 'Phoenix', algo_name))
    
    icews_det = pd.concat(icews_all, ignore_index=True) if icews_all else pd.DataFrame()
    phoenix_det = pd.concat(phoenix_all, ignore_index=True) if phoenix_all else pd.DataFrame()
    
    if not icews_det.empty:
        icews_det.to_csv(output_dir / 'ICEWS_vs_GDELT_五种算法_相关性分析_详细结果.csv', index=False, encoding='utf-8-sig')
        print(f"  ICEWS_vs_GDELT_详细结果 ({len(icews_det)}行)")
    if not phoenix_det.empty:
        phoenix_det.to_csv(output_dir / 'Phoenix_vs_GDELT_五种算法_相关性分析_详细结果.csv', index=False, encoding='utf-8-sig')
        print(f"  Phoenix_vs_GDELT_详细结果 ({len(phoenix_det)}行)")
    
    icews_sum = CorrelationAnalyzer.summarize(icews_det)
    phoenix_sum = CorrelationAnalyzer.summarize(phoenix_det)
    if not icews_sum.empty:
        icews_sum.to_csv(output_dir / 'ICEWS_vs_GDELT_五种算法_相关性分析_汇总结果.csv', index=False, encoding='utf-8-sig')
        print(f"  ICEWS_vs_GDELT_汇总结果")
    if not phoenix_sum.empty:
        phoenix_sum.to_csv(output_dir / 'Phoenix_vs_GDELT_五种算法_相关性分析_汇总结果.csv', index=False, encoding='utf-8-sig')
        print(f"  Phoenix_vs_GDELT_汇总结果")
    
    # 5. 报告
    report_path = output_dir / '计算汇总报告_三库五种算法_2002-2019.txt'
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write("=" * 80 + "\n三库五种算法综合分析 汇总报告\n" + "=" * 80 + "\n")
        f.write(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"时间窗口: {Config.START_DATE} 至 {Config.END_DATE}\n")
        f.write(f"数据库: GDELT, ICEWS, Phoenix\n")
        f.write(f"算法: 算术平均, 几何平均(几何插值), 中位数, 二次平均(SQM), 绝对值加权(λ={Config.ABS_LAMBDA})\n")
        f.write(f"插值规则: 几何平均→对数空间几何插值; 其他→线性插值; 首尾均不插值\n\n")
        
        f.write("输出文件清单:\n")
        f.write("-" * 60 + "\n")
        f.write("1. 月度指数 (15个): {DB}_{Algo}_月度指数_2002-2019.csv\n")
        f.write("2. 汇总文件 (3个): {DB}_五种算法_月度指数_汇总_2002-2019.csv\n")
        f.write("3. 详细相关 (2个): {DB}_vs_GDELT_五种算法_相关性分析_详细结果.csv\n")
        f.write("4. 汇总相关 (2个): {DB}_vs_GDELT_五种算法_相关性分析_汇总结果.csv\n\n")
        
        if not icews_sum.empty:
            f.write("ICEWS vs GDELT 汇总统计:\n")
            for _, r in icews_sum.iterrows():
                f.write(f"  {r['Algorithm']:22s} | {r['Index_Type']:15s} | Spearman中位数={r['Spearman_Median']:.4f} | 显著比例={r['Spearman_SigPct']:.1f}%\n")
            f.write("\n")
        if not phoenix_sum.empty:
            f.write("Phoenix vs GDELT 汇总统计:\n")
            for _, r in phoenix_sum.iterrows():
                f.write(f"  {r['Algorithm']:22s} | {r['Index_Type']:15s} | Spearman中位数={r['Spearman_Median']:.4f} | 显著比例={r['Spearman_SigPct']:.1f}%\n")
            f.write("\n")
        f.write("=" * 80 + "\n")
    
    print(f"\n汇总报告: {report_path}")
    print("=" * 80)
    print("全部完成！")
    print("=" * 80)


if __name__ == "__main__":
    main()
