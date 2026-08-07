import pandas as pd
import numpy as np
from datetime import datetime, timedelta
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
    OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\中位数月度聚合算法（由日到月）"
    
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
    
    # 显著性水平
    SIGNIFICANCE_LEVEL = 0.05


# ==================== 数据加载与预处理 ====================
class DataLoader:
    """数据加载和预处理类"""
    
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


# ==================== 中位数月度聚合计算器 ====================
class MedianMonthlyAggregator:
    """
    中位数月度聚合算法（由日到月）
    
    核心逻辑：
    1. 日级聚合：每天所有事件的Goldstein分数取算术平均 → "日综合分值"
    2. 月度聚合：对该月所有"活跃日"的日综合分值取中位数
    3. 辅助指标："活跃日比例" = 当月活跃天数 / 当月总天数
    
    无事件日处理（方案B）：
    - 不将无事件日直接赋0纳入中位数（避免0值扭曲"典型日子"）
    - 但记录活跃日比例，反映该月双边关系的活跃度
    """
    
    def __init__(self):
        pass
    
    def compute_daily_scores(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        计算日综合分值：将每天所有事件的Goldstein分数取算术平均
        
        输入: DataFrame[EventDate, Partner, Direction, Score]
        输出: DataFrame[Date, Partner, Direction, DailyMeanScore, EventCount]
        """
        if df.empty:
            return pd.DataFrame()
        
        df = df.copy()
        df['Date'] = df['EventDate'].dt.date
        
        # 按 Partner + Direction + Date 分组，计算日度算术平均
        daily = df.groupby(['Partner', 'Direction', 'Date']).agg(
            DailyMeanScore=('Score', 'mean'),
            EventCount=('Score', 'count')
        ).reset_index()
        
        daily['Date'] = pd.to_datetime(daily['Date'])
        return daily
    
    def compute_monthly_median(self, daily_df: pd.DataFrame, partner: str, direction: str) -> pd.DataFrame:
        """
        计算月度中位数聚合
        
        对指定Partner和Direction：
        1. 提取该Partner+Direction的日综合分值序列
        2. 按月份分组，对活跃日的日综合分值取中位数
        3. 计算活跃日比例
        
        返回: DataFrame[Partner, Index_Type, YearMonth, MedianScore, ActiveDayRatio, TotalDays, ActiveDays, AvgDailyEvents]
        """
        if daily_df.empty:
            return pd.DataFrame()
        
        # 筛选数据
        if direction == "Aggregated":
            sub = daily_df[daily_df['Partner'] == partner].copy()
        else:
            sub = daily_df[(daily_df['Partner'] == partner) & (daily_df['Direction'] == direction)].copy()
        
        if sub.empty:
            return pd.DataFrame()
        
        sub['YearMonth'] = sub['Date'].dt.to_period('M').astype(str)
        
        results = []
        for ym, group in sub.groupby('YearMonth'):
            # 该月的所有天数（从该月第一天到最后一天）
            year, month = int(ym.split('-')[0]), int(ym.split('-')[1])
            month_start = pd.Timestamp(year=year, month=month, day=1)
            if month == 12:
                month_end = pd.Timestamp(year=year+1, month=1, day=1)
            else:
                month_end = pd.Timestamp(year=year, month=month+1, day=1)
            total_days_in_month = (month_end - month_start).days
            
            # 活跃日：有事件的日子（Aggregated方向按唯一日期计算，避免双方向同日重复计数）
            if direction == "Aggregated":
                active_days = group['Date'].nunique()
            else:
                active_days = len(group)
            active_day_ratio = active_days / total_days_in_month if total_days_in_month > 0 else 0
            
            # 活跃日的日综合分值的中位数（核心指标）
            median_score = group['DailyMeanScore'].median()
            
            # 补充统计
            mean_score = group['DailyMeanScore'].mean()
            std_score = group['DailyMeanScore'].std()
            min_score = group['DailyMeanScore'].min()
            max_score = group['DailyMeanScore'].max()
            avg_daily_events = group['EventCount'].mean()
            total_events = group['EventCount'].sum()
            
            results.append({
                'Partner': partner,
                'Index_Type': direction,
                'YearMonth': ym,
                'MedianScore': median_score,
                'ActiveDayRatio': active_day_ratio,
                'TotalDays': total_days_in_month,
                'ActiveDays': active_days,
                'MeanScore': mean_score,
                'StdScore': std_score,
                'MinScore': min_score,
                'MaxScore': max_score,
                'AvgDailyEvents': avg_daily_events,
                'TotalEvents': total_events
            })
        
        return pd.DataFrame(results)
    
    def compute_all(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        计算所有Partner×Direction的月度中位数聚合
        
        返回两个DataFrame：
        - median_df: 主指标（活跃日中位数）
        - ratio_df: 辅助指标（活跃日比例）
        两者格式统一为 [Partner, Index_Type, YearMonth, Index_Value]
        """
        if df.empty:
            return pd.DataFrame(), pd.DataFrame()
        
        # 第一步：计算日综合分值
        daily_df = self.compute_daily_scores(df)
        print(f"  日综合分值: {len(daily_df)} 条")
        
        # 第二步：计算月度中位数
        all_monthly = []
        for direction in Config.INDEX_TYPES:
            for partner in Config.TARGET_COUNTRIES:
                monthly = self.compute_monthly_median(daily_df, partner, direction)
                if not monthly.empty:
                    all_monthly.append(monthly)
        
        if not all_monthly:
            return pd.DataFrame(), pd.DataFrame()
        
        monthly_all = pd.concat(all_monthly, ignore_index=True)
        
        # 整理为两种输出格式
        # 主指标：MedianScore
        median_df = monthly_all[['Partner', 'Index_Type', 'YearMonth', 'MedianScore']].copy()
        median_df = median_df.rename(columns={'MedianScore': 'Index_Value'})
        median_df['Indicator'] = 'Median_ActiveDays'
        
        # 辅助指标：ActiveDayRatio
        ratio_df = monthly_all[['Partner', 'Index_Type', 'YearMonth', 'ActiveDayRatio']].copy()
        ratio_df = ratio_df.rename(columns={'ActiveDayRatio': 'Index_Value'})
        ratio_df['Indicator'] = 'ActiveDay_Ratio'
        
        # 合并（便于统一处理）
        combined_df = pd.concat([median_df, ratio_df], ignore_index=True)
        
        return combined_df, monthly_all


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
        计算Median_ActiveDays指标的相关性
        """
        g_median = gdelt_df[gdelt_df['Indicator'] == 'Median_ActiveDays']
        i_median = icews_df[icews_df['Indicator'] == 'Median_ActiveDays']
        
        all_corr = []
        for partner in Config.TARGET_COUNTRIES:
            for idx_type in Config.INDEX_TYPES:
                g = g_median[(g_median['Partner']==partner) & (g_median['Index_Type']==idx_type)]
                i = i_median[(i_median['Partner']==partner) & (i_median['Index_Type']==idx_type)]
                if g.empty or i.empty:
                    continue
                
                g_ser = g.set_index('YearMonth')['Index_Value']
                i_ser = i.set_index('YearMonth')['Index_Value']
                common = g_ser.index.intersection(i_ser.index)
                if len(common) < 2:
                    continue
                
                corr = self.calc_corr(g_ser.loc[common].values, i_ser.loc[common].values)
                all_corr.append({
                    'Partner': partner, 'Index_Type': idx_type,
                    'Spearman_r': corr['Sp'], 'Spearman_p': corr['Sp_p'],
                    'Pearson_r': corr['Pr'], 'Pearson_p': corr['Pr_p'],
                    'N_Months': len(common)
                })
        
        detail_df = pd.DataFrame(all_corr)
        
        # 汇总
        summary = []
        sub = detail_df[detail_df['Index_Type']=='Aggregated']
        if not sub.empty:
            sig = sub[sub['Spearman_p'] < Config.SIGNIFICANCE_LEVEL]
            summary.append({
                'Algorithm': 'Median_ActiveDays',
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
    print("中位数月度聚合算法（由日到月）")
    print("核心设计：日度算术平均 → 活跃日中位数 + 活跃日比例")
    print("=" * 70)
    print(f"开始: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    os.makedirs(Config.OUTPUT_DIR, exist_ok=True)
    
    # 加载数据
    loader = DataLoader()
    gdelt_raw = loader.load_gdelt_data(Config.GDELT_PATH)
    icews_raw = loader.load_icews_data(Config.ICEWS_PATH)
    
    # 初始化计算器
    aggregator = MedianMonthlyAggregator()
    analyzer = CorrelationAnalyzer()
    
    # 计算GDELT
    print("\n【1/4】计算GDELT中位数月度聚合...")
    gdelt_combined, gdelt_full = aggregator.compute_all(gdelt_raw)
    print(f"  合并结果: {len(gdelt_combined)} 条")
    
    # 计算ICEWS
    print("\n【2/4】计算ICEWS中位数月度聚合...")
    icews_combined, icews_full = aggregator.compute_all(icews_raw)
    print(f"  合并结果: {len(icews_combined)} 条")
    
    # 保存结果
    print("\n【3/4】保存结果...")
    if not gdelt_combined.empty:
        gdelt_combined.to_csv(os.path.join(Config.OUTPUT_DIR, "GDELT_中位数月度聚合_由日到月.csv"), 
                             index=False, encoding='utf-8-sig')
    if not icews_combined.empty:
        icews_combined.to_csv(os.path.join(Config.OUTPUT_DIR, "ICEWS_中位数月度聚合_由日到月.csv"), 
                             index=False, encoding='utf-8-sig')
    
    # 保存完整统计（包含Mean/Std/Min/Max等）
    if not gdelt_full.empty:
        gdelt_full.to_csv(os.path.join(Config.OUTPUT_DIR, "GDELT_中位数月度聚合_详细统计_由日到月.csv"), 
                         index=False, encoding='utf-8-sig')
    if not icews_full.empty:
        icews_full.to_csv(os.path.join(Config.OUTPUT_DIR, "ICEWS_中位数月度聚合_详细统计_由日到月.csv"), 
                         index=False, encoding='utf-8-sig')
    
    # 计算相关性
    print("\n【4/4】计算跨库相关性...")
    detail_corr, summary_corr = analyzer.compute_correlations(gdelt_combined, icews_combined)
    
    if not detail_corr.empty:
        detail_corr.to_csv(os.path.join(Config.OUTPUT_DIR, "GDELT_ICEWS_相关性分析_详细结果_中位数月度聚合.csv"), 
                          index=False, encoding='utf-8-sig')
        print(f"  详细结果: {len(detail_corr)} 条")
    
    if not summary_corr.empty:
        summary_corr.to_csv(os.path.join(Config.OUTPUT_DIR, "GDELT_ICEWS_相关性分析_汇总结果_中位数月度聚合.csv"), 
                           index=False, encoding='utf-8-sig')
        print("\n=== 汇总结果 (Aggregated队列) ===")
        print(summary_corr.to_string(index=False))
    
    # 打印逐国详细结果
    if not detail_corr.empty:
        print("\n=== Aggregated队列 逐国Spearman ===")
        agg = detail_corr[detail_corr['Index_Type']=='Aggregated'].sort_values('Spearman_r', ascending=False)
        print(agg[['Partner','Spearman_r','Spearman_p','N_Months']].to_string(index=False))
    
    print("\n" + "=" * 70)
    print(f"完成: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"输出目录: {Config.OUTPUT_DIR}")
    print("=" * 70)


if __name__ == "__main__":
    main()
