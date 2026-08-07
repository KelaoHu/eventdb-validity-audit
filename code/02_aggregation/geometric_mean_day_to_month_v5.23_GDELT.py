import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional, Set
import os
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# ==================== 配置区域 ====================
class Config:
    """全局配置类"""
    
    # 输入文件路径
    GDELT_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\GDELT2002_25国严格双边事件_20260414_213010.csv"
    
    # 输出目录
    OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\GDELT数据库几何平均原始文件"
    
    # 平移常数
    SHIFT_CONSTANT = 11  # 将分数从[-10, 10]平移到[1, 21]
    
    # 时间范围
    START_DATE = "2002-01-01"
    END_DATE = "2025-12-31"  # 到2025年12月
    
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
    
    # 国家代码到全称映射（用于GDELT）
    COUNTRY_CODE_TO_NAME = {
        "JPN": "Japan",
        "USA": "United States", 
        "KOR": "South Korea",
        "DEU": "Germany",
        "MYS": "Malaysia",
        "SGP": "Singapore",
        "RUS": "Russia",
        "GBR": "United Kingdom",
        "NLD": "Netherlands",
        "AUS": "Australia",
        "ITA": "Italy",
        "THA": "Thailand",
        "FRA": "France",
        "IDN": "Indonesia",
        "CAN": "Canada",
        "PHL": "Philippines",
        "SAU": "Saudi Arabia",
        "IND": "India",
        "BEL": "Belgium",
        "BRA": "Brazil",
        "MEX": "Mexico",
        "ARE": "United Arab Emirates",
        "IRN": "Iran",
        "ESP": "Spain",
        "VNM": "Vietnam"
    }


# ==================== 数据加载与预处理 ====================
class DataLoader:
    """数据加载和预处理类"""
    
    @staticmethod
    def load_gdelt_data(file_path: str) -> pd.DataFrame:
        """加载GDELT数据并进行预处理"""
        print(f"正在加载GDELT数据: {file_path}")
        
        try:
            df = pd.read_csv(file_path, encoding='utf-8-sig', low_memory=False)
            print(f"  GDELT原始数据形状: {df.shape}")
            
            df['EventDate'] = pd.to_datetime(df['EventDate'], errors='coerce')
            
            start_date = pd.Timestamp(Config.START_DATE)
            end_date = pd.Timestamp(Config.END_DATE)
            df = df[(df['EventDate'] >= start_date) & (df['EventDate'] <= end_date)].copy()
            print(f"  时间筛选后数据形状: {df.shape}")
            
            df['Score'] = pd.to_numeric(df['GoldsteinScale'], errors='coerce')
            df['Direction'] = df['Direction'].str.strip()
            df['Partner'] = df.apply(DataLoader._extract_partner_from_direction, axis=1)
            df = df[['EventDate', 'Partner', 'Direction', 'Score']].dropna()
            
            print(f"  GDELT处理后数据形状: {df.shape}")
            print(f"  GDELT Score范围: [{df['Score'].min():.2f}, {df['Score'].max():.2f}]")
            print(f"  GDELT Partner数量: {df['Partner'].nunique()}")
            
            return df
            
        except Exception as e:
            print(f"  GDELT数据加载失败: {e}")
            import traceback
            traceback.print_exc()
            return pd.DataFrame()
    
    @staticmethod
    def _extract_partner_from_direction(row) -> str:
        """从方向列提取伙伴国名称"""
        try:
            direction = str(row['Direction']).strip()
            
            if direction == "CHN->Partner":
                if 'Actor2CountryCode' in row:
                    code = str(row['Actor2CountryCode']).strip()
                    return Config.COUNTRY_CODE_TO_NAME.get(code, code)
            elif direction == "Partner->CHN":
                if 'Actor1CountryCode' in row:
                    code = str(row['Actor1CountryCode']).strip()
                    return Config.COUNTRY_CODE_TO_NAME.get(code, code)
        except:
            pass
        
        return ""


# ==================== 两步几何平均算法实现（由日到月）====================
class DailyToMonthlyGeometricMeanCalculator:
    """由日到月的两步几何平均计算器"""
    
    @staticmethod
    def _calculate_daily_geometric_mean(scores: pd.Series) -> float:
        """
        计算单日几何平均分数
        步骤：先平移，取几何平均，再还原
        """
        if len(scores) == 0:
            return np.nan
        
        scores_shifted = scores + Config.SHIFT_CONSTANT
        
        # 确保所有值都大于0
        if (scores_shifted <= 0).any():
            return np.nan
        
        # 计算几何平均的对数形式
        log_mean = np.log(scores_shifted).mean()
        geometric_mean_shifted = np.exp(log_mean)
        
        # 还原到原始尺度
        daily_score = geometric_mean_shifted - Config.SHIFT_CONSTANT
        
        return daily_score
    
    @staticmethod
    def calculate_daily_to_monthly_geometric_mean(df: pd.DataFrame) -> pd.DataFrame:
        """
        计算由日到月的两步几何平均指数
        步骤：
        1. 对每个国家、每个方向、每一天，计算该天所有事件分数的几何平均，得到每日分数
        2. 对每个月，计算该月内所有有事件的日的每日分数的算术平均，得到月度分数
        
        返回: DataFrame with columns [YearMonth, Partner, Index_Type, Index_Value]
        """
        if df.empty:
            print(f"  GDELT: 数据为空，跳过计算")
            return pd.DataFrame()
        
        print(f"  GDELT: 开始计算由日到月的两步几何平均指数，数据形状: {df.shape}")
        
        # 第一步：计算每日几何平均分数
        print(f"  GDELT: 第一步 - 计算每日几何平均分数...")
        
        direction_daily_results = []
        direction_groups = df.groupby(['Partner', 'Direction', 'EventDate'])
        total_direction_groups = len(direction_groups)
        print(f"  GDELT: 共有 {total_direction_groups} 个方向-日期分组需要计算")
        
        for i, ((partner, direction, date), group) in enumerate(direction_groups, 1):
            if i % 10000 == 0:
                print(f"  GDELT: 每日几何平均计算进度: {i}/{total_direction_groups} ({i/total_direction_groups*100:.1f}%)")
            
            daily_score = DailyToMonthlyGeometricMeanCalculator._calculate_daily_geometric_mean(group['Score'])
            if not np.isnan(daily_score):
                direction_daily_results.append({
                    'Partner': partner,
                    'Direction': direction,
                    'Date': date,
                    'YearMonth': date.strftime('%Y-%m'),
                    'DailyScore': daily_score
                })
        
        if not direction_daily_results:
            print(f"  GDELT: 没有有效的每日几何平均分数")
            return pd.DataFrame()
        
        direction_daily_df = pd.DataFrame(direction_daily_results)
        print(f"  GDELT: 每日几何平均分数计算完成，共 {len(direction_daily_df)} 条记录")
        
        # 为汇总（Aggregated）计算每日几何平均
        print(f"  GDELT: 为汇总（Aggregated）计算每日几何平均分数...")
        aggregated_daily_results = []
        
        aggregated_groups = df.groupby(['Partner', 'EventDate'])
        total_aggregated_groups = len(aggregated_groups)
        
        for i, ((partner, date), group) in enumerate(aggregated_groups, 1):
            if i % 10000 == 0:
                print(f"  GDELT: 汇总每日几何平均计算进度: {i}/{total_aggregated_groups} ({i/total_aggregated_groups*100:.1f}%)")
            
            daily_score = DailyToMonthlyGeometricMeanCalculator._calculate_daily_geometric_mean(group['Score'])
            if not np.isnan(daily_score):
                aggregated_daily_results.append({
                    'Partner': partner,
                    'Direction': 'Aggregated',
                    'Date': date,
                    'YearMonth': date.strftime('%Y-%m'),
                    'DailyScore': daily_score
                })
        
        if aggregated_daily_results:
            aggregated_daily_df = pd.DataFrame(aggregated_daily_results)
            print(f"  GDELT: 汇总每日几何平均分数计算完成，共 {len(aggregated_daily_df)} 条记录")
            daily_df = pd.concat([direction_daily_df, aggregated_daily_df], ignore_index=True)
        else:
            daily_df = direction_daily_df
        
        print(f"  GDELT: 每日几何平均分数总计 {len(daily_df)} 条记录")
        
        # 第二步：计算月度平均分数（基于每日几何平均分数）
        print(f"  GDELT: 第二步 - 计算月度平均分数（基于每日几何平均分数）...")
        
        monthly_results = []
        monthly_groups = daily_df.groupby(['Partner', 'Direction', 'YearMonth'])
        
        for (partner, direction, month), group in monthly_groups:
            monthly_score = group['DailyScore'].mean()
            if not np.isnan(monthly_score):
                monthly_results.append({
                    'Partner': partner,
                    'Index_Type': direction,
                    'YearMonth': month,
                    'Index_Value': monthly_score
                })
        
        result_df = pd.DataFrame(monthly_results)
        print(f"  GDELT: 月度平均分数计算完成，共 {len(result_df)} 条记录")
        
        return result_df
    
    @staticmethod
    def create_complete_time_series(monthly_df: pd.DataFrame) -> pd.DataFrame:
        """
        创建完整的时间序列，包含所有月份，并应用线性插值
        """
        if monthly_df.empty:
            print(f"  GDELT: 月度指数数据为空，跳过创建完整时间序列")
            return pd.DataFrame()
        
        print(f"  GDELT: 开始创建完整时间序列...")
        
        dates = pd.period_range(start=Config.START_DATE, end=Config.END_DATE, freq='M')
        all_months = [str(p) for p in dates]
        
        all_partners = monthly_df['Partner'].unique()
        all_index_types = monthly_df['Index_Type'].unique()
        
        print(f"  GDELT: 时间范围: {len(all_months)} 个月")
        print(f"  GDELT: 伙伴国数量: {len(all_partners)}")
        print(f"  GDELT: 指数类型: {all_index_types}")
        
        complete_data = []
        
        for partner in all_partners:
            for index_type in all_index_types:
                mask = (monthly_df['Partner'] == partner) & (monthly_df['Index_Type'] == index_type)
                partner_data = monthly_df[mask].copy()
                
                if partner_data.empty:
                    continue
                
                time_series = pd.Series(index=all_months, dtype=float)
                
                for _, row in partner_data.iterrows():
                    time_series[row['YearMonth']] = row['Index_Value']
                
                time_series_interpolated = DailyToMonthlyGeometricMeanCalculator._log_space_interpolation(time_series)
                
                for month, value in time_series_interpolated.items():
                    complete_data.append({
                        'Partner': partner,
                        'Index_Type': index_type,
                        'YearMonth': month,
                        'Index_Value': value
                    })
        
        result_df = pd.DataFrame(complete_data)
        print(f"  GDELT: 完整时间序列创建完成，共 {len(result_df)} 条记录")
        
        return result_df
    
    @staticmethod
    def _log_space_interpolation(series: pd.Series) -> pd.Series:
        """
        在对数空间应用线性插值（只插中间，首尾保留NaN）
        步骤：平移→取对数→线性插值→指数化→还原平移
        """
        if series.isna().all():
            return series
        
        temp_series = series.copy()
        temp_series.index = pd.to_datetime(temp_series.index, format='%Y-%m')
        
        # 1. 平移
        shifted_series = temp_series + Config.SHIFT_CONSTANT
        
        # 2. 取对数（忽略NaN）
        log_series = shifted_series.apply(lambda x: np.log(x) if x > 0 else np.nan)
        
        # 3. 线性插值（仅中间缺失值，首尾留空）
        log_series_interpolated = log_series.interpolate(method='linear')
        
        # 4. 指数化还原
        shifted_series_interpolated = np.exp(log_series_interpolated)
        
        # 5. 还原到原始尺度
        result_series = shifted_series_interpolated - Config.SHIFT_CONSTANT
        
        result_series.index = result_series.index.strftime('%Y-%m')
        return result_series


# ==================== 结果输出 ====================
class ResultExporter:
    """结果输出器"""
    
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def export_monthly_indices(self, gdelt_df: pd.DataFrame):
        """导出月度指数"""
        print("\n导出月度指数...")
        
        if not gdelt_df.empty:
            gdelt_path = self.output_dir / "GDELT_月度几何平均指数_由日到月.csv"
            gdelt_df.to_csv(gdelt_path, index=False, encoding='utf-8-sig')
            print(f"GDELT指数已保存: {gdelt_path}")
            print(f"GDELT文件形状: {gdelt_df.shape}")
            print(f"GDELT前5行示例:")
            print(gdelt_df.head())
        else:
            print("警告: GDELT结果为空，跳过保存")


# ==================== 主程序 ====================
def main():
    """主程序"""
    print("=" * 80)
    print("GDELT月度几何平均算法（由日到月）计算系统")
    print("=" * 80)
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"平移常数: {Config.SHIFT_CONSTANT}")
    print(f"时间范围: {Config.START_DATE} 至 {Config.END_DATE}")
    print(f"输出目录: {Config.OUTPUT_DIR}")
    print("=" * 80)
    
    output_dir = Path(Config.OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    exporter = ResultExporter(Config.OUTPUT_DIR)
    
    try:
        gdelt_data = DataLoader.load_gdelt_data(Config.GDELT_PATH)
        
        if gdelt_data.empty:
            print("错误: GDELT数据加载失败，程序终止")
            return
        
        print(f"\n{'='*60}")
        print(f"开始计算由日到月的两步几何平均指数")
        print(f"{'='*60}")
        
        gdelt_monthly = DailyToMonthlyGeometricMeanCalculator.calculate_daily_to_monthly_geometric_mean(gdelt_data)
        gdelt_results = DailyToMonthlyGeometricMeanCalculator.create_complete_time_series(gdelt_monthly)
        
        print(f"\nGDELT结果形状: {gdelt_results.shape if not gdelt_results.empty else '空'}")
        
        exporter.export_monthly_indices(gdelt_results)
        
        print("\n" + "=" * 80)
        print("计算完成！")
        print(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 80)
        
    except Exception as e:
        print(f"\n程序执行出错: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
