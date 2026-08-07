# GDELT与ICEWS双库政治关系指数一致性验证 - 二次平均算法（由日到月）

import pandas as pd
import numpy as np
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import os
from pathlib import Path
import warnings
from scipy import stats
warnings.filterwarnings('ignore')

# ==================== 配置区域 ====================
class Config:
    """全局配置类"""
    
    # 输入文件路径
    GDELT_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\GDELT2002_25国严格双边事件_20260414_213010.csv"
    ICEWS_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\ICEWS_中国与25国双边政治事件_2002-01-01_to_2023-04-10.csv"
    
    # 输出目录
    OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\二次平均算法（由日到月）"
    
    # 时间范围
    START_DATE = "2002-01-01"
    END_DATE = "2023-03-31"
    
    # 目标国家列表
    TARGET_COUNTRIES = [
        "Japan", "United States", "South Korea", "Germany", "Malaysia",
        "Singapore", "Russia", "United Kingdom", "Netherlands", "Australia",
        "Italy", "Thailand", "France", "Indonesia", "Canada",
        "Philippines", "Saudi Arabia", "India", "Belgium", "Brazil",
        "Mexico", "United Arab Emirates", "Iran", "Spain", "Vietnam"
    ]
    
    # 指数类型
    INDEX_TYPES = ["Aggregated", "CHN->Partner", "Partner->CHN"]
    
    # 国家代码到全称映射（GDELT）
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
    
    # 算法参数
    EPSILON = 1e-10  # 防止除零
    MIN_EVENTS_PER_DAY = 1
    MIN_DAYS_PER_MONTH = 1
    
    # 显著性水平
    SIGNIFICANCE_LEVEL = 0.05


# ==================== 数据加载与预处理 ====================
class DataLoader:
    """数据加载和预处理类 - 适配用户实际数据格式"""
    
    @staticmethod
    def load_gdelt_data(file_path: str) -> pd.DataFrame:
        """加载GDELT数据"""
        print(f"正在加载GDELT数据: {file_path}")
        df = pd.read_csv(file_path, encoding='utf-8-sig', low_memory=False)
        print(f"  GDELT原始数据形状: {df.shape}")
        
        df['EventDate'] = pd.to_datetime(df['EventDate'], errors='coerce')
        start_date = pd.Timestamp(Config.START_DATE)
        end_date = pd.Timestamp(Config.END_DATE)
        df = df[(df['EventDate'] >= start_date) & (df['EventDate'] <= end_date)].copy()
        
        df['Score'] = pd.to_numeric(df['GoldsteinScale'], errors='coerce')
        df['Direction'] = df['Direction'].str.strip()
        df['Partner'] = df.apply(DataLoader._extract_partner_gdelt, axis=1)
        
        df = df[['EventDate', 'Partner', 'Direction', 'Score']].dropna()
        print(f"  GDELT处理后: {df.shape}, Score范围: [{df['Score'].min():.2f}, {df['Score'].max():.2f}]")
        return df
    
    @staticmethod
    def load_icews_data(file_path: str) -> pd.DataFrame:
        """加载ICEWS数据"""
        print(f"正在加载ICEWS数据: {file_path}")
        df = pd.read_csv(file_path, encoding='utf-8-sig', low_memory=False)
        print(f"  ICEWS原始数据形状: {df.shape}")
        
        df['EventDate'] = pd.to_datetime(df['Event Date'], errors='coerce')
        start_date = pd.Timestamp(Config.START_DATE)
        end_date = pd.Timestamp(Config.END_DATE)
        df = df[(df['EventDate'] >= start_date) & (df['EventDate'] <= end_date)].copy()
        
        df['Score'] = pd.to_numeric(df['Intensity'], errors='coerce')
        df['Direction'] = df['_event_direction'].apply(DataLoader._convert_icews_direction)
        df['Partner'] = df.apply(DataLoader._extract_partner_icews, axis=1)
        
        df = df[['EventDate', 'Partner', 'Direction', 'Score']].dropna()
        print(f"  ICEWS处理后: {df.shape}, Score范围: [{df['Score'].min():.2f}, {df['Score'].max():.2f}]")
        return df
    
    @staticmethod
    def _extract_partner_gdelt(row) -> str:
        direction = str(row.get('Direction', '')).strip()
        code = str(row.get('Actor2CountryCode' if direction == "CHN->Partner" else 'Actor1CountryCode', '')).strip()
        return Config.COUNTRY_CODE_TO_NAME.get(code, code)
    
    @staticmethod
    def _convert_icews_direction(direction_str: str) -> str:
        if pd.isna(direction_str): return "Unknown"
        direction_str = str(direction_str).strip()
        if "China -> " in direction_str: return "CHN->Partner"
        if " -> China" in direction_str: return "Partner->CHN"
        return "Unknown"
    
    @staticmethod
    def _extract_partner_icews(row) -> str:
        for col in row.index:
            if 'direction' in str(col).lower():
                d = str(row[col])
                if 'China -> ' in d: return d.split('China -> ')[1].strip()
                if ' -> China' in d: return d.split(' -> China')[0].strip()
        return ""


# ==================== 二次平均计算器 ====================
class QuadraticMeanCalculator:
    """
    二次平均算法实现（由日到月）
    
    算法1: SQM (Signed Quadratic Mean)
        M = sign(mean(x)) * sqrt(mean(x^2))
        - 平方放大极端值，开方恢复量纲，符号保留方向
    
    算法2: MCM (Modified Contraharmonic Mean)
        M = (sum(x_i^2) / sum(|x_i| + ε)) * sign(mean(x))
        - 分子平方放大极端值，分母绝对值避免正负抵消
    """
    
    def __init__(self, epsilon: float = Config.EPSILON):
        self.epsilon = epsilon
    
    def signed_quadratic_mean(self, values: np.ndarray) -> float:
        """
        符号二次均值 (SQM)
        M = sign(mean(x)) * sqrt(mean(x^2))
        """
        values = np.asarray(values)
        values = values[~np.isnan(values)]
        if len(values) == 0:
            return np.nan
        
        mean_val = np.mean(values)
        mean_sq = np.mean(values ** 2)
        
        if mean_sq == 0:
            return 0.0
        
        return np.sign(mean_val) * np.sqrt(mean_sq)
    
    def modified_contraharmonic_mean(self, values: np.ndarray) -> float:
        """
        修正的Contraharmonic均值 (MCM)
        M = (sum(x_i^2) / sum(|x_i| + ε)) * sign(mean(x))
        """
        values = np.asarray(values)
        values = values[~np.isnan(values)]
        if len(values) == 0:
            return np.nan
        
        sum_sq = np.sum(values ** 2)
        sum_abs = np.sum(np.abs(values)) + self.epsilon
        mean_val = np.mean(values)
        
        if sum_abs == 0:
            return 0.0
        
        return (sum_sq / sum_abs) * np.sign(mean_val)
    
    def weighted_sqm(self, values: np.ndarray, weights: np.ndarray) -> float:
        """
        加权符号二次均值
        M = sign(weighted_mean(x)) * sqrt(weighted_mean(x^2))
        """
        values = np.asarray(values)
        weights = np.asarray(weights)
        
        mask = ~np.isnan(values)
        values = values[mask]
        weights = weights[mask]
        
        if len(values) == 0:
            return np.nan
        
        weights = weights / np.sum(weights)
        weighted_mean = np.sum(weights * values)
        weighted_mean_sq = np.sum(weights * (values ** 2))
        
        if weighted_mean_sq == 0:
            return 0.0
        
        return np.sign(weighted_mean) * np.sqrt(weighted_mean_sq)
    
    def calculate_daily_to_monthly(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        由日到月的二次平均计算
        
        步骤:
        1. 按日分组，对日内事件计算SQM和MCM
        2. 按月分组，对日度结果计算加权SQM/MCM（权重为日事件数）
        """
        if df.empty:
            return pd.DataFrame()
        
        df = df.copy()
        df['YearMonth'] = df['EventDate'].dt.to_period('M').astype(str)
        df['DateOnly'] = df['EventDate'].dt.date
        
        # 第一步：日度二次平均
        daily_results = []
        for (ym, d), group in df.groupby(['YearMonth', 'DateOnly']):
            scores = group['Score'].values
            if len(scores) < Config.MIN_EVENTS_PER_DAY:
                continue
            
            sqm = self.signed_quadratic_mean(scores)
            mcm = self.modified_contraharmonic_mean(scores)
            
            if not np.isnan(sqm) or not np.isnan(mcm):
                daily_results.append({
                    'YearMonth': ym,
                    'DateOnly': d,
                    'Daily_SQM': sqm,
                    'Daily_MCM': mcm,
                    'EventCount': len(scores)
                })
        
        if not daily_results:
            return pd.DataFrame()
        
        daily_df = pd.DataFrame(daily_results)
        
        # 第二步：月度加权二次平均
        monthly_results = []
        for ym, group in daily_df.groupby('YearMonth'):
            if len(group) < Config.MIN_DAYS_PER_MONTH:
                continue
            
            sqm_values = group['Daily_SQM'].values
            mcm_values = group['Daily_MCM'].values
            weights = group['EventCount'].values
            
            monthly_sqm = self.weighted_sqm(sqm_values, weights)
            monthly_mcm = self.weighted_sqm(mcm_values, weights)
            monthly_arith = np.average(sqm_values, weights=weights)  # 基线对比
            
            monthly_results.append({
                'YearMonth': ym,
                'Monthly_SQM': monthly_sqm,
                'Monthly_MCM': monthly_mcm,
                'Monthly_Arithmetic': monthly_arith,
                'TotalEvents': group['EventCount'].sum(),
                'DaysCount': len(group)
            })
        
        return pd.DataFrame(monthly_results)
    
    def compute_index(self, df: pd.DataFrame, partner: str, direction: str) -> pd.DataFrame:
        """
        计算特定Partner和Direction的月度指数
        返回: DataFrame[Partner, Index_Type, YearMonth, Index_Value]
        """
        if direction == "Aggregated":
            sub = df[df['Partner'] == partner].copy()
        else:
            sub = df[(df['Partner'] == partner) & (df['Direction'] == direction)].copy()
        
        if sub.empty:
            return pd.DataFrame()
        
        monthly = self.calculate_daily_to_monthly(sub)
        if monthly.empty:
            return pd.DataFrame()
        
        results = []
        for _, row in monthly.iterrows():
            ym = str(row['YearMonth'])
            
            # SQM指数
            results.append({
                'Partner': partner, 'Index_Type': direction,
                'YearMonth': ym, 'Index_Value': row['Monthly_SQM'],
                'Algorithm': 'SQM'
            })
            # MCM指数
            results.append({
                'Partner': partner, 'Index_Type': direction,
                'YearMonth': ym, 'Index_Value': row['Monthly_MCM'],
                'Algorithm': 'MCM'
            })
            # 算术平均基线
            results.append({
                'Partner': partner, 'Index_Type': direction,
                'YearMonth': ym, 'Index_Value': row['Monthly_Arithmetic'],
                'Algorithm': 'Arithmetic_Baseline'
            })
        
        return pd.DataFrame(results)


# ==================== 相关性分析器 ====================
class CorrelationAnalyzer:
    """计算跨库相关性"""
    
    @staticmethod
    def calc_corr(g_vals, i_vals):
        aligned = pd.DataFrame({'G': g_vals, 'I': i_vals}).dropna()
        if len(aligned) < 2:
            return {'Sp': np.nan, 'Sp_p': np.nan, 'Pr': np.nan, 'Pr_p': np.nan}
        try:
            sr = stats.spearmanr(aligned['G'], aligned['I'])
            pr = stats.pearsonr(aligned['G'], aligned['I'])
            return {'Sp': sr.correlation, 'Sp_p': sr.pvalue, 'Pr': pr.statistic, 'Pr_p': pr.pvalue}
        except:
            return {'Sp': np.nan, 'Sp_p': np.nan, 'Pr': np.nan, 'Pr_p': np.nan}
    
    def compute_correlations(self, gdelt_df: pd.DataFrame, icews_df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """
        计算所有Partner×Direction×Algorithm的相关性
        返回: (detail_df, summary_df)
        """
        all_corr = []
        
        for partner in Config.TARGET_COUNTRIES:
            for idx_type in Config.INDEX_TYPES:
                for algorithm in ['SQM', 'MCM', 'Arithmetic_Baseline']:
                    g = gdelt_df[(gdelt_df['Partner']==partner) & 
                                 (gdelt_df['Index_Type']==idx_type) &
                                 (gdelt_df['Algorithm']==algorithm)]
                    i = icews_df[(icews_df['Partner']==partner) & 
                                 (icews_df['Index_Type']==idx_type) &
                                 (icews_df['Algorithm']==algorithm)]
                    if g.empty or i.empty:
                        continue
                    
                    g_ser = g.set_index('YearMonth')['Index_Value']
                    i_ser = i.set_index('YearMonth')['Index_Value']
                    common = g_ser.index.intersection(i_ser.index)
                    if len(common) < 2:
                        continue
                    
                    corr = self.calc_corr(g_ser.loc[common].values, i_ser.loc[common].values)
                    all_corr.append({
                        'Partner': partner, 'Index_Type': idx_type, 'Algorithm': algorithm,
                        'Spearman_r': corr['Sp'], 'Spearman_p': corr['Sp_p'],
                        'Pearson_r': corr['Pr'], 'Pearson_p': corr['Pr_p'],
                        'N_Months': len(common)
                    })
        
        detail_df = pd.DataFrame(all_corr)
        
        # 汇总统计
        summary = []
        for algorithm in ['SQM', 'MCM', 'Arithmetic_Baseline']:
            sub = detail_df[(detail_df['Algorithm']==algorithm) & (detail_df['Index_Type']=='Aggregated')]
            if sub.empty:
                continue
            sig = sub[sub['Spearman_p'] < Config.SIGNIFICANCE_LEVEL]
            summary.append({
                'Algorithm': algorithm,
                'Spearman_Median': sub['Spearman_r'].median(),
                'Spearman_Mean': sub['Spearman_r'].mean(),
                'Spearman_Min': sub['Spearman_r'].min(),
                'Spearman_Max': sub['Spearman_r'].max(),
                'Significant_Count': len(sig),
                'Total_Count': len(sub)
            })
        
        summary_df = pd.DataFrame(summary)
        return detail_df, summary_df


# ==================== 主函数 ====================
def main():
    print("=" * 70)
    print("GDELT与ICEWS双库政治关系指数一致性验证")
    print("二次平均算法（由日到月）")
    print("=" * 70)
    print(f"开始: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    os.makedirs(Config.OUTPUT_DIR, exist_ok=True)
    
    # 加载数据
    loader = DataLoader()
    gdelt_raw = loader.load_gdelt_data(Config.GDELT_PATH)
    icews_raw = loader.load_icews_data(Config.ICEWS_PATH)
    
    # 初始化计算器
    calculator = QuadraticMeanCalculator()
    analyzer = CorrelationAnalyzer()
    
    # 计算所有指数
    all_gdelt, all_icews = [], []
    
    for direction in Config.INDEX_TYPES:
        print(f"\n【处理方向: {direction}】")
        for j, partner in enumerate(Config.TARGET_COUNTRIES, 1):
            gdelt_idx = calculator.compute_index(gdelt_raw, partner, direction)
            if not gdelt_idx.empty:
                all_gdelt.append(gdelt_idx)
            
            icews_idx = calculator.compute_index(icews_raw, partner, direction)
            if not icews_idx.empty:
                all_icews.append(icews_idx)
            
            if j % 5 == 0:
                print(f"  进度: {j}/25 ({direction})")
    
    gdelt_results = pd.concat(all_gdelt, ignore_index=True) if all_gdelt else pd.DataFrame()
    icews_results = pd.concat(all_icews, ignore_index=True) if all_icews else pd.DataFrame()
    
    print(f"\nGDELT结果: {len(gdelt_results)} 条")
    print(f"ICEWS结果: {len(icews_results)} 条")
    
    # 保存结果
    if not gdelt_results.empty:
        gdelt_results.to_csv(os.path.join(Config.OUTPUT_DIR, "GDELT_二次平均指数_由日到月.csv"), 
                             index=False, encoding='utf-8-sig')
    if not icews_results.empty:
        icews_results.to_csv(os.path.join(Config.OUTPUT_DIR, "ICEWS_二次平均指数_由日到月.csv"), 
                             index=False, encoding='utf-8-sig')
    
    # 计算相关性
    print("\n计算跨库相关性...")
    detail_corr, summary_corr = analyzer.compute_correlations(gdelt_results, icews_results)
    
    if not detail_corr.empty:
        detail_corr.to_csv(os.path.join(Config.OUTPUT_DIR, "GDELT_ICEWS_相关性分析_详细结果_二次平均.csv"), 
                          index=False, encoding='utf-8-sig')
        print(f"  详细结果: {len(detail_corr)} 条")
    
    if not summary_corr.empty:
        summary_corr.to_csv(os.path.join(Config.OUTPUT_DIR, "GDELT_ICEWS_相关性分析_汇总结果_二次平均.csv"), 
                           index=False, encoding='utf-8-sig')
        print("\n=== 汇总结果 (Aggregated队列) ===")
        print(summary_corr.to_string(index=False))
    
    print("\n" + "=" * 70)
    print(f"完成: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"输出目录: {Config.OUTPUT_DIR}")
    print("=" * 70)


if __name__ == "__main__":
    main()
