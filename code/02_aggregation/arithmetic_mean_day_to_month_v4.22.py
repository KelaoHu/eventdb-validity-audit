import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional, Set
import os
from pathlib import Path
import warnings
from scipy import stats
warnings.filterwarnings('ignore')

# ==================== 配置区域 ====================
class Config:
    """全局配置类"""
    
    # 输入文件路径
    GDELT_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\2002_25国严格双边事件_20260414_213010.csv"
    ICEWS_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\ICEWS_中国与25国双边政治事件_2002-01-01_to_2023-04-10.csv"
    
    # 输出目录
    OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\月度算术平均算法（由日到月）"
    
    # 时间范围
    START_DATE = "2002-01-01"
    END_DATE = "2023-03-31"  # 到2023年3月
    
    # 目标国家列表（使用ICEWS全称）
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
            # 读取数据
            df = pd.read_csv(file_path, encoding='utf-8-sig', low_memory=False)
            print(f"  GDELT原始数据形状: {df.shape}")
            
            # 转换日期
            df['EventDate'] = pd.to_datetime(df['EventDate'], errors='coerce')
            
            # 筛选时间范围
            start_date = pd.Timestamp(Config.START_DATE)
            end_date = pd.Timestamp(Config.END_DATE)
            df = df[(df['EventDate'] >= start_date) & (df['EventDate'] <= end_date)].copy()
            print(f"  时间筛选后数据形状: {df.shape}")
            
            # 提取分数 (GoldsteinScale)
            df['Score'] = pd.to_numeric(df['GoldsteinScale'], errors='coerce')
            
            # 提取方向
            df['Direction'] = df['Direction'].str.strip()
            
            # 提取伙伴国
            df['Partner'] = df.apply(DataLoader._extract_partner_from_direction, axis=1, args=('GDELT',))
            
            # 只保留必要的列
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
    def load_icews_data(file_path: str) -> pd.DataFrame:
        """加载ICEWS数据并进行预处理"""
        print(f"正在加载ICEWS数据: {file_path}")
        
        try:
            # 读取数据
            df = pd.read_csv(file_path, encoding='utf-8-sig', low_memory=False)
            print(f"  ICEWS原始数据形状: {df.shape}")
            
            # 转换日期
            df['EventDate'] = pd.to_datetime(df['Event Date'], errors='coerce')
            
            # 筛选时间范围
            start_date = pd.Timestamp(Config.START_DATE)
            end_date = pd.Timestamp(Config.END_DATE)
            df = df[(df['EventDate'] >= start_date) & (df['EventDate'] <= end_date)].copy()
            print(f"  时间筛选后数据形状: {df.shape}")
            
            # 提取分数 (Intensity)
            df['Score'] = pd.to_numeric(df['Intensity'], errors='coerce')
            
            # 提取方向
            if '_event_direction' in df.columns:
                df['Direction'] = df['_event_direction'].apply(DataLoader._convert_icews_direction)
            else:
                df['Direction'] = df.apply(DataLoader._infer_icews_direction, axis=1)
            
            # 提取伙伴国
            df['Partner'] = df.apply(DataLoader._extract_partner_from_direction, axis=1, args=('ICEWS',))
            
            # 只保留必要的列
            df = df[['EventDate', 'Partner', 'Direction', 'Score']].dropna()
            
            print(f"  ICEWS处理后数据形状: {df.shape}")
            print(f"  ICEWS Score范围: [{df['Score'].min():.2f}, {df['Score'].max():.2f}]")
            print(f"  ICEWS Partner数量: {df['Partner'].nunique()}")
            
            return df
            
        except Exception as e:
            print(f"  ICEWS数据加载失败: {e}")
            import traceback
            traceback.print_exc()
            return pd.DataFrame()
    
    @staticmethod
    def _convert_icews_direction(direction_str: str) -> str:
        """转换ICEWS方向格式"""
        if pd.isna(direction_str):
            return "Unknown"
        
        direction_str = str(direction_str).strip()
        
        if "China -> " in direction_str:
            return "CHN->Partner"
        elif " -> China" in direction_str:
            return "Partner->CHN"
        else:
            return "Unknown"
    
    @staticmethod
    def _infer_icews_direction(row) -> str:
        """推断ICEWS方向"""
        try:
            source = str(row.get('Source Country', ''))
            target = str(row.get('Target Country', ''))
            
            if 'China' in source or 'china' in source.lower():
                return "CHN->Partner"
            elif 'China' in target or 'china' in target.lower():
                return "Partner->CHN"
        except:
            pass
        return "Unknown"
    
    @staticmethod
    def _extract_partner_from_direction(row, dataset: str) -> str:
        """从方向列提取伙伴国名称"""
        try:
            direction = str(row['Direction']).strip()
            
            if dataset == 'GDELT':
                if direction == "CHN->Partner":
                    if 'Actor2CountryCode' in row:
                        code = str(row['Actor2CountryCode']).strip()
                        return Config.COUNTRY_CODE_TO_NAME.get(code, code)
                elif direction == "Partner->CHN":
                    if 'Actor1CountryCode' in row:
                        code = str(row['Actor1CountryCode']).strip()
                        return Config.COUNTRY_CODE_TO_NAME.get(code, code)
            elif dataset == 'ICEWS':
                if '_event_direction' in row:
                    dir_str = str(row['_event_direction']).strip()
                    if "China -> " in dir_str:
                        partner = dir_str.split("China -> ")[1].strip()
                        return partner
                    elif " -> China" in dir_str:
                        partner = dir_str.split(" -> China")[0].strip()
                        return partner
                
                if direction == "CHN->Partner":
                    if 'Target Country' in row:
                        return str(row['Target Country']).strip()
                elif direction == "Partner->CHN":
                    if 'Source Country' in row:
                        return str(row['Source Country']).strip()
        except:
            pass
        
        return ""


# ==================== 两步算术平均算法实现 ====================
class DailyToMonthlyAverageCalculator:
    """由日到月的两步算术平均计算器"""
    
    @staticmethod
    def calculate_daily_to_monthly_average(df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        """
        计算由日到月的两步算术平均指数
        步骤：
        1. 对每个国家、每个方向、每一天，计算该天所有事件分数的算术平均，得到每日分数
        2. 对每个月，计算该月内所有有事件的日的每日分数的算术平均，得到月度分数
        
        返回: DataFrame with columns [YearMonth, Partner, Index_Type, Index_Value]
        """
        if df.empty:
            print(f"  {dataset_name}: 数据为空，跳过计算")
            return pd.DataFrame()
        
        print(f"  {dataset_name}: 开始计算由日到月的两步算术平均指数，数据形状: {df.shape}")
        
        # 第一步：计算每日平均分数
        print(f"  {dataset_name}: 第一步 - 计算每日平均分数...")
        
        # 为各方向计算每日平均
        direction_daily_results = []
        
        # 按国家、方向、日期分组
        direction_groups = df.groupby(['Partner', 'Direction', 'EventDate'])
        total_direction_groups = len(direction_groups)
        print(f"  {dataset_name}: 共有 {total_direction_groups} 个方向-日期分组需要计算")
        
        for i, ((partner, direction, date), group) in enumerate(direction_groups, 1):
            if i % 10000 == 0:
                print(f"  {dataset_name}: 每日平均计算进度: {i}/{total_direction_groups} ({i/total_direction_groups*100:.1f}%)")
            
            daily_score = group['Score'].mean()
            if not np.isnan(daily_score):
                direction_daily_results.append({
                    'Partner': partner,
                    'Direction': direction,
                    'Date': date,
                    'YearMonth': date.strftime('%Y-%m'),
                    'DailyScore': daily_score
                })
        
        if not direction_daily_results:
            print(f"  {dataset_name}: 没有有效的每日平均分数")
            return pd.DataFrame()
        
        direction_daily_df = pd.DataFrame(direction_daily_results)
        print(f"  {dataset_name}: 每日平均分数计算完成，共 {len(direction_daily_df)} 条记录")
        
        # 为汇总（Aggregated）计算每日平均
        print(f"  {dataset_name}: 为汇总（Aggregated）计算每日平均分数...")
        aggregated_daily_results = []
        
        aggregated_groups = df.groupby(['Partner', 'EventDate'])
        total_aggregated_groups = len(aggregated_groups)
        
        for i, ((partner, date), group) in enumerate(aggregated_groups, 1):
            if i % 10000 == 0:
                print(f"  {dataset_name}: 汇总每日平均计算进度: {i}/{total_aggregated_groups} ({i/total_aggregated_groups*100:.1f}%)")
            
            daily_score = group['Score'].mean()
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
            print(f"  {dataset_name}: 汇总每日平均分数计算完成，共 {len(aggregated_daily_df)} 条记录")
            
            # 合并方向每日分数和汇总每日分数
            daily_df = pd.concat([direction_daily_df, aggregated_daily_df], ignore_index=True)
        else:
            daily_df = direction_daily_df
        
        print(f"  {dataset_name}: 每日平均分数总计 {len(daily_df)} 条记录")
        
        # 第二步：计算月度平均分数（基于每日平均分数）
        print(f"  {dataset_name}: 第二步 - 计算月度平均分数（基于每日平均分数）...")
        
        monthly_results = []
        
        # 按国家、方向、年月分组
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
        print(f"  {dataset_name}: 月度平均分数计算完成，共 {len(result_df)} 条记录")
        
        return result_df
    
    @staticmethod
    def create_complete_time_series(monthly_df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        """
        创建完整的时间序列，包含所有月份，并应用线性插值
        """
        if monthly_df.empty:
            print(f"  {dataset_name}: 月度指数数据为空，跳过创建完整时间序列")
            return pd.DataFrame()
        
        print(f"  {dataset_name}: 开始创建完整时间序列...")
        
        # 生成完整的时间范围
        dates = pd.period_range(start=Config.START_DATE, end=Config.END_DATE, freq='M')
        all_months = [str(p) for p in dates]
        
        all_partners = monthly_df['Partner'].unique()
        all_index_types = monthly_df['Index_Type'].unique()
        
        print(f"  {dataset_name}: 时间范围: {len(all_months)} 个月")
        print(f"  {dataset_name}: 伙伴国数量: {len(all_partners)}")
        print(f"  {dataset_name}: 指数类型: {all_index_types}")
        
        complete_data = []
        
        for partner in all_partners:
            for index_type in all_index_types:
                # 筛选当前组合的数据
                mask = (monthly_df['Partner'] == partner) & (monthly_df['Index_Type'] == index_type)
                partner_data = monthly_df[mask].copy()
                
                if partner_data.empty:
                    # 如果没有任何数据，跳过
                    continue
                
                # 创建完整的时间序列
                time_series = pd.Series(index=all_months, dtype=float)
                
                # 填充已有的值
                for _, row in partner_data.iterrows():
                    time_series[row['YearMonth']] = row['Index_Value']
                
                # 应用线性插值
                time_series_interpolated = DailyToMonthlyAverageCalculator._linear_interpolation(time_series)
                
                # 添加到结果
                for month, value in time_series_interpolated.items():
                    complete_data.append({
                        'Partner': partner,
                        'Index_Type': index_type,
                        'YearMonth': month,
                        'Index_Value': value
                    })
        
        result_df = pd.DataFrame(complete_data)
        print(f"  {dataset_name}: 完整时间序列创建完成，共 {len(result_df)} 条记录")
        
        return result_df
    
    @staticmethod
    def _linear_interpolation(series: pd.Series) -> pd.Series:
        """
        对时间序列应用线性插值（已修改：仅插中间，首尾留空）
        """
        if series.isna().all():
            return series
        
        # 将字符串索引转为时间索引以便使用pandas插值
        temp_series = series.copy()
        temp_series.index = pd.to_datetime(temp_series.index, format='%Y-%m')
        
        # 使用Pandas标准线性插值
        # method='linear': 线性插值
        # 默认行为：仅对中间缺失值进行插值，首尾保持NaN
        temp_series_interpolated = temp_series.interpolate(method='linear')
        
        # 把索引转回字符串
        temp_series_interpolated.index = temp_series_interpolated.index.strftime('%Y-%m')
        
        return temp_series_interpolated


# ==================== 计算管理器 ====================
class ComputeManager:
    """计算管理器"""
    
    def __init__(self):
        self.gdelt_data = None
        self.icews_data = None
        
    def load_all_data(self):
        """加载所有数据"""
        print("开始加载数据...")
        
        # 加载数据
        self.gdelt_data = DataLoader.load_gdelt_data(Config.GDELT_PATH)
        self.icews_data = DataLoader.load_icews_data(Config.ICEWS_PATH)
        
        print("数据加载完成")
        
    def compute_all_indices(self) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """
        计算所有指数
        返回: (gdelt_results, icews_results)
        """
        print(f"\n{'='*60}")
        print(f"开始计算由日到月的两步算术平均指数")
        print(f"{'='*60}")
        
        # 计算GDELT
        print(f"\n计算GDELT数据:")
        gdelt_monthly = DailyToMonthlyAverageCalculator.calculate_daily_to_monthly_average(self.gdelt_data, "GDELT")
        gdelt_results = DailyToMonthlyAverageCalculator.create_complete_time_series(gdelt_monthly, "GDELT")
        
        # 计算ICEWS
        print(f"\n计算ICEWS数据:")
        icews_monthly = DailyToMonthlyAverageCalculator.calculate_daily_to_monthly_average(self.icews_data, "ICEWS")
        icews_results = DailyToMonthlyAverageCalculator.create_complete_time_series(icews_monthly, "ICEWS")
        
        print(f"\n计算完成")
        print(f"GDELT结果形状: {gdelt_results.shape if not gdelt_results.empty else '空'}")
        print(f"ICEWS结果形状: {icews_results.shape if not icews_results.empty else '空'}")
        
        return gdelt_results, icews_results


# ==================== 相关性分析 ====================
class CorrelationAnalyzer:
    """相关性分析器"""
    
    @staticmethod
    def calculate_correlations(gdelt_series: pd.Series, icews_series: pd.Series) -> dict:
        """计算皮尔逊和斯皮尔曼相关系数"""
        
        # 确保序列对齐
        aligned_data = pd.DataFrame({
            'GDELT': gdelt_series,
            'ICEWS': icews_series
        }).dropna()
        
        if len(aligned_data) < 2:
            return {
                'pearson_r': np.nan,
                'pearson_p': np.nan,
                'spearman_r': np.nan,
                'spearman_p': np.nan
            }
        
        try:
            # 计算皮尔逊相关系数
            pearson_result = stats.pearsonr(aligned_data['GDELT'], aligned_data['ICEWS'])
            
            # 计算斯皮尔曼相关系数
            spearman_result = stats.spearmanr(aligned_data['GDELT'], aligned_data['ICEWS'])
            
            return {
                'pearson_r': pearson_result.statistic,
                'pearson_p': pearson_result.pvalue,
                'spearman_r': spearman_result.correlation,
                'spearman_p': spearman_result.pvalue
            }
        except Exception as e:
            print(f"相关性计算失败: {e}")
            return {
                'pearson_r': np.nan,
                'pearson_p': np.nan,
                'spearman_r': np.nan,
                'spearman_p': np.nan
            }
    
    @staticmethod
    def analyze_all_correlations(gdelt_df: pd.DataFrame, icews_df: pd.DataFrame) -> pd.DataFrame:
        """分析所有相关性"""
        print("\n开始相关性分析...")
        
        all_correlations = []
        
        # 获取所有目标国家
        target_countries = Config.TARGET_COUNTRIES
        index_types = Config.INDEX_TYPES
        
        print(f"分析配置:")
        print(f"  目标国家数: {len(target_countries)}")
        print(f"  指数类型数: {len(index_types)}")
        print(f"  总计算组合: {len(target_countries) * len(index_types)}")
        
        total_combinations = len(target_countries) * len(index_types)
        current_combination = 0
        
        for partner in target_countries:
            for index_type in index_types:
                current_combination += 1
                
                if current_combination % 10 == 0:
                    print(f"  进度: {current_combination}/{total_combinations} ({current_combination/total_combinations*100:.1f}%)")
                
                # 提取时间序列
                mask_gdelt = (gdelt_df['Partner'] == partner) & (gdelt_df['Index_Type'] == index_type)
                mask_icews = (icews_df['Partner'] == partner) & (icews_df['Index_Type'] == index_type)
                
                gdelt_subset = gdelt_df.loc[mask_gdelt]
                icews_subset = icews_df.loc[mask_icews]
                
                if gdelt_subset.empty or icews_subset.empty:
                    continue
                
                gdelt_series = gdelt_subset.set_index('YearMonth')['Index_Value']
                icews_series = icews_subset.set_index('YearMonth')['Index_Value']
                
                # 确保序列对齐
                common_index = gdelt_series.index.intersection(icews_series.index)
                if len(common_index) < 2:
                    continue
                
                gdelt_series = gdelt_series.loc[common_index]
                icews_series = icews_series.loc[common_index]
                
                # 计算相关性
                corr_result = CorrelationAnalyzer.calculate_correlations(gdelt_series, icews_series)
                
                all_correlations.append({
                    'Partner': partner,
                    'Index_Type': index_type,
                    'Pearson_r': corr_result['pearson_r'],
                    'Pearson_p': corr_result['pearson_p'],
                    'Spearman_r': corr_result['spearman_r'],
                    'Spearman_p': corr_result['spearman_p']
                })
        
        result_df = pd.DataFrame(all_correlations)
        print(f"\n相关性分析完成，共 {len(result_df)} 条有效记录")
        
        return result_df
    
    @staticmethod
    def analyze_aggregated_correlations(gdelt_df: pd.DataFrame, icews_df: pd.DataFrame) -> pd.DataFrame:
        """分析汇总（Aggregated）相关性"""
        print("\n开始分析汇总（Aggregated）相关性...")
        
        aggregated_correlations = []
        
        # 获取所有目标国家
        target_countries = Config.TARGET_COUNTRIES
        
        for partner in target_countries:
            # 提取汇总（Aggregated）时间序列
            mask_gdelt = (gdelt_df['Partner'] == partner) & (gdelt_df['Index_Type'] == 'Aggregated')
            mask_icews = (icews_df['Partner'] == partner) & (icews_df['Index_Type'] == 'Aggregated')
            
            gdelt_subset = gdelt_df.loc[mask_gdelt]
            icews_subset = icews_df.loc[mask_icews]
            
            if gdelt_subset.empty or icews_subset.empty:
                continue
            
            gdelt_series = gdelt_subset.set_index('YearMonth')['Index_Value']
            icews_series = icews_subset.set_index('YearMonth')['Index_Value']
            
            # 确保序列对齐
            common_index = gdelt_series.index.intersection(icews_series.index)
            if len(common_index) < 2:
                continue
            
            gdelt_series = gdelt_series.loc[common_index]
            icews_series = icews_series.loc[common_index]
            
            # 计算相关性
            corr_result = CorrelationAnalyzer.calculate_correlations(gdelt_series, icews_series)
            
            aggregated_correlations.append({
                'Partner': partner,
                'Pearson_r': corr_result['pearson_r'],
                'Pearson_p': corr_result['pearson_p'],
                'Spearman_r': corr_result['spearman_r'],
                'Spearman_p': corr_result['spearman_p']
            })
        
        result_df = pd.DataFrame(aggregated_correlations)
        print(f"汇总相关性分析完成，共 {len(result_df)} 条有效记录")
        
        return result_df


# ==================== 结果输出 ====================
class ResultExporter:
    """结果输出器"""
    
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def export_monthly_indices(self, gdelt_df: pd.DataFrame, icews_df: pd.DataFrame):
        """导出月度指数"""
        print("\n导出月度指数...")
        
        # 导出GDELT结果
        if not gdelt_df.empty:
            gdelt_path = self.output_dir / "GDELT_月度算术平均指数_由日到月.csv"
            gdelt_df.to_csv(gdelt_path, index=False, encoding='utf-8-sig')
            print(f"GDELT指数已保存: {gdelt_path}")
            print(f"GDELT文件形状: {gdelt_df.shape}")
        else:
            print("警告: GDELT结果为空，跳过保存")
        
        # 导出ICEWS结果
        if not icews_df.empty:
            icews_path = self.output_dir / "ICEWS_月度算术平均指数_由日到月.csv"
            icews_df.to_csv(icews_path, index=False, encoding='utf-8-sig')
            print(f"ICEWS指数已保存: {icews_path}")
            print(f"ICEWS文件形状: {icews_df.shape}")
        else:
            print("警告: ICEWS结果为空，跳过保存")
    
    def export_correlation_analysis(self, correlations_df: pd.DataFrame):
        """导出相关性分析结果（75个队列）"""
        print("\n导出相关性分析结果（75个队列）...")
        
        if correlations_df.empty:
            print("警告: 相关性分析结果为空，跳过保存")
            return
        
        # 保存结果
        corr_path = self.output_dir / "GDELT_ICEWS_相关性分析_详细结果_由日到月.csv"
        correlations_df.to_csv(corr_path, index=False, encoding='utf-8-sig')
        print(f"相关性分析结果已保存: {corr_path}")
        print(f"相关性文件形状: {correlations_df.shape}")
        
        return correlations_df
    
    def export_aggregated_correlation_analysis(self, aggregated_corr_df: pd.DataFrame):
        """导出汇总相关性分析结果（25个队列）"""
        print("\n导出汇总相关性分析结果（25个队列）...")
        
        if aggregated_corr_df.empty:
            print("警告: 汇总相关性分析结果为空，跳过保存")
            return
        
        # 保存结果
        agg_corr_path = self.output_dir / "GDELT_ICEWS_相关性分析_汇总结果_由日到月.csv"
        aggregated_corr_df.to_csv(agg_corr_path, index=False, encoding='utf-8-sig')
        print(f"汇总相关性分析结果已保存: {agg_corr_path}")
        print(f"汇总相关性文件形状: {aggregated_corr_df.shape}")
        
        return aggregated_corr_df


# ==================== 主程序 ====================
def main():
    """主程序"""
    print("=" * 80)
    print("月度算术平均算法（由日到月）计算系统")
    print("=" * 80)
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"时间范围: {Config.START_DATE} 至 {Config.END_DATE}")
    print(f"输出目录: {Config.OUTPUT_DIR}")
    print("=" * 80)
    
    # 初始化输出目录
    output_dir = Path(Config.OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 初始化管理器
    manager = ComputeManager()
    exporter = ResultExporter(Config.OUTPUT_DIR)
    
    try:
        # 1. 加载数据
        manager.load_all_data()
        
        # 2. 计算所有指数
        gdelt_results, icews_results = manager.compute_all_indices()
        
        # 3. 导出月度指数
        exporter.export_monthly_indices(gdelt_results, icews_results)
        
        # 4. 相关性分析（75个队列）
        correlations_df = CorrelationAnalyzer.analyze_all_correlations(gdelt_results, icews_results)
        if not correlations_df.empty:
            correlations_df = exporter.export_correlation_analysis(correlations_df)
            
            # 5. 相关性分析（25个汇总队列）
            aggregated_corr_df = CorrelationAnalyzer.analyze_aggregated_correlations(gdelt_results, icews_results)
            exporter.export_aggregated_correlation_analysis(aggregated_corr_df)
        
        # 6. 生成汇总报告
        generate_summary_report(gdelt_results, icews_results, correlations_df, 
                               aggregated_corr_df if 'aggregated_corr_df' in locals() else pd.DataFrame())
        
        print("\n" + "=" * 80)
        print("计算完成！")
        print(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 80)
        
    except Exception as e:
        print(f"\n程序执行出错: {e}")
        import traceback
        traceback.print_exc()


def generate_summary_report(gdelt_results, icews_results, correlations_df, aggregated_corr_df):
    """生成汇总报告"""
    report_path = Path(Config.OUTPUT_DIR) / "计算汇总报告_由日到月.txt"
    
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write("=" * 80 + "\n")
        f.write("月度算术平均算法（由日到月）计算汇总报告\n")
        f.write("=" * 80 + "\n")
        f.write(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"计算参数:\n")
        f.write(f"  - 算法: 两步算术平均（先日平均，再月平均）\n")
        f.write(f"  - 时间范围: {Config.START_DATE} 至 {Config.END_DATE}\n")
        f.write(f"  - 目标国家: 25个\n")
        f.write(f"  - 指数类型: {Config.INDEX_TYPES}\n")
        f.write("\n")
        
        # 数据统计
        f.write("数据统计:\n")
        if not correlations_df.empty:
            total_pairs = len(correlations_df['Partner'].unique()) * len(correlations_df['Index_Type'].unique())
            f.write(f"  - 总队列数: {total_pairs}\n")
            f.write(f"  - 总相关性计算数: {len(correlations_df)}\n")
        else:
            f.write(f"  - 相关性分析结果为空\n")
        
        # 相关性强度统计
        if not correlations_df.empty:
            f.write("\n相关性强度统计（斯皮尔曼）:\n")
            if 'Spearman_r' in correlations_df.columns:
                spearman_bins = pd.cut(correlations_df['Spearman_r'].abs(), 
                                     bins=[0, 0.2, 0.4, 0.6, 0.8, 1.0])
                bin_counts = spearman_bins.value_counts().sort_index()
                for bin_range, count in bin_counts.items():
                    f.write(f"  - {bin_range}: {count} 个队列\n")
            
            # 显著相关性统计
            f.write("\n显著相关性统计:\n")
            if 'Spearman_p' in correlations_df.columns:
                significant_spearman = (correlations_df['Spearman_p'] < 0.05).sum()
                f.write(f"  - 斯皮尔曼显著（p<0.05）: {significant_spearman} 个队列\n")
                f.write(f"  - 斯皮尔曼显著比例: {significant_spearman/len(correlations_df)*100:.1f}%\n")
            
            if 'Pearson_p' in correlations_df.columns:
                significant_pearson = (correlations_df['Pearson_p'] < 0.05).sum()
                f.write(f"  - 皮尔逊显著（p<0.05）: {significant_pearson} 个队列\n")
                f.write(f"  - 皮尔逊显著比例: {significant_pearson/len(correlations_df)*100:.1f}%\n")
        
        # 汇总相关性统计
        if not aggregated_corr_df.empty:
            f.write("\n汇总相关性统计（Aggregated）:\n")
            if 'Spearman_r' in aggregated_corr_df.columns:
                avg_agg_spearman = aggregated_corr_df['Spearman_r'].abs().mean()
                f.write(f"  - 平均斯皮尔曼相关系数绝对值: {avg_agg_spearman:.4f}\n")
            
            if 'Pearson_r' in aggregated_corr_df.columns:
                avg_agg_pearson = aggregated_corr_df['Pearson_r'].abs().mean()
                f.write(f"  - 平均皮尔逊相关系数绝对值: {avg_agg_pearson:.4f}\n")
        
        f.write("\n" + "=" * 80 + "\n")
        f.write("文件输出清单:\n")
        f.write("=" * 80 + "\n")
        f.write("1. GDELT_月度算术平均指数_由日到月.csv - GDELT数据库月度指数（由日到月）\n")
        f.write("2. ICEWS_月度算术平均指数_由日到月.csv - ICEWS数据库月度指数（由日到月）\n")
        f.write("3. GDELT_ICEWS_相关性分析_详细结果_由日到月.csv - 详细相关性分析结果（75个队列）\n")
        f.write("4. GDELT_ICEWS_相关性分析_汇总结果_由日到月.csv - 汇总相关性分析结果（25个Aggregated队列）\n")
        f.write("5. 计算汇总报告_由日到月.txt - 本报告\n")
    
    print(f"\n汇总报告已保存: {report_path}")


if __name__ == "__main__":
    main()
