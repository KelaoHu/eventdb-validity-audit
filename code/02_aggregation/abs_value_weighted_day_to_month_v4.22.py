import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional, Set
import os
from pathlib import Path
import warnings
from scipy import stats
from multiprocessing import Pool, cpu_count, Manager
from functools import partial
import traceback
warnings.filterwarnings('ignore')

# ==================== 配置区域 ====================
class Config:
    """全局配置类"""
    
    # 输入文件路径
    GDELT_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\2002_25国严格双边事件_20260414_213010.csv"
    ICEWS_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\原数据副本\ICEWS_中国与25国双边政治事件_2002-01-01_to_2023-04-10.csv"
    
    # 输出目录
    OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\绝对值加权法"
    
    # 计算参数
    LAMBDA_VALUES = [i/2 for i in range(0, 41)]  # [0, 0.5, 1.0, ..., 20.0] 共41个值
    SIGNIFICANCE_LEVEL = 0.05  # 显著性水平
    
    # 进程数配置
    MAX_PROCESSES = 8  # 使用CPU核心数-2，至少1个
    
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
        "UAE": "United Arab Emirates",  # 添加UAE的映射
        "IRN": "Iran",
        "ESP": "Spain",
        "VNM": "Vietnam"
    }
    
    # ICEWS方向映射
    ICEWS_DIRECTION_MAP = {
        "China -> ": "CHN->Partner",
        " -> China": "Partner->CHN"
    }


# ==================== 数据加载与预处理 ====================
class DataLoader:
    """数据加载和预处理类"""
    
    @staticmethod
    def load_gdelt_data(file_path: str) -> pd.DataFrame:
        """加载GDELT数据并进行预处理 - 简化版"""
        print(f"正在加载GDELT数据: {file_path}", flush=True)
        
        try:
            # 读取数据
            df = pd.read_csv(file_path, encoding='utf-8-sig', low_memory=False)
            print(f"  GDELT原始数据形状: {df.shape}", flush=True)
            
            # 转换日期
            df['EventDate'] = pd.to_datetime(df['EventDate'], errors='coerce')
            
            # 筛选时间范围
            start_date = pd.Timestamp(Config.START_DATE)
            end_date = pd.Timestamp(Config.END_DATE)
            df = df[(df['EventDate'] >= start_date) & (df['EventDate'] <= end_date)].copy()
            print(f"  时间筛选后数据形状: {df.shape}", flush=True)
            
            # 提取分数 (GoldsteinScale)
            df['Score'] = pd.to_numeric(df['GoldsteinScale'], errors='coerce')
            
            # 提取国家信息
            df['Direction'] = df['Direction'].str.strip()
            
            # 提取伙伴国
            df['Partner'] = df.apply(DataLoader._extract_partner_from_direction, axis=1, args=('GDELT',))
            
            # 只保留必要的列
            df = df[['EventDate', 'Partner', 'Direction', 'Score']].dropna()
            
            print(f"  GDELT处理后数据形状: {df.shape}", flush=True)
            print(f"  GDELT提取到的国家: {sorted(df['Partner'].unique())}", flush=True)
            
            return df
            
        except Exception as e:
            print(f"  GDELT数据加载失败: {e}", flush=True)
            traceback.print_exc()
            return pd.DataFrame()
    
    @staticmethod
    def load_icews_data(file_path: str) -> pd.DataFrame:
        """加载ICEWS数据并进行预处理 - 简化版"""
        print(f"正在加载ICEWS数据: {file_path}", flush=True)
        
        try:
            # 读取数据
            df = pd.read_csv(file_path, encoding='utf-8-sig', low_memory=False)
            print(f"  ICEWS原始数据形状: {df.shape}", flush=True)
            
            # 转换日期
            df['EventDate'] = pd.to_datetime(df['Event Date'], errors='coerce')
            
            # 筛选时间范围
            start_date = pd.Timestamp(Config.START_DATE)
            end_date = pd.Timestamp(Config.END_DATE)
            df = df[(df['EventDate'] >= start_date) & (df['EventDate'] <= end_date)].copy()
            print(f"  时间筛选后数据形状: {df.shape}", flush=True)
            
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
            
            print(f"  ICEWS处理后数据形状: {df.shape}", flush=True)
            print(f"  ICEWS提取到的国家: {sorted(df['Partner'].unique())}", flush=True)
            
            return df
            
        except Exception as e:
            print(f"  ICEWS数据加载失败: {e}", flush=True)
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
                        return dir_str.split("China -> ")[1].strip()
                    elif " -> China" in dir_str:
                        return dir_str.split(" -> China")[0].strip()
                if direction == "CHN->Partner":
                    if 'Target Country' in row:
                        return str(row['Target Country']).strip()
                elif direction == "Partner->CHN":
                    if 'Source Country' in row:
                        return str(row['Source Country']).strip()
        except:
            pass
        return ""


# ==================== 核心算法实现 ====================
class PoliticalRelationIndexCalculator:
    """政治关系指数计算器"""
    
    def __init__(self, lambda_val: float):
        self.lambda_val = lambda_val
    
    def calculate_daily_weighted_score(self, scores: pd.Series) -> float:
        """计算日加权分数"""
        if len(scores) == 0:
            return np.nan
        weights = 1 + self.lambda_val * np.abs(scores) / 10
        weighted_sum = np.sum(weights * scores)
        weight_sum = np.sum(weights)
        if weight_sum == 0:
            return np.nan
        return weighted_sum / weight_sum
    
    def calculate_monthly_index(self, df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        """
        计算月度指数（已修改Aggregated逻辑，与第二段代码对齐）
        """
        if df.empty:
            print(f"  {dataset_name}: 数据为空，跳过计算", flush=True)
            return pd.DataFrame()
        
        print(f"  {dataset_name}: 开始计算月度指数，数据形状: {df.shape}", flush=True)
        
        # 【优化】避免在原DataFrame上直接修改，使用assign创建副本
        df_work = df.assign(YearMonth=df['EventDate'].dt.to_period('M').astype(str))
        
        # 1. 为各方向计算每日平均
        direction_daily_results = []
        direction_groups = df_work.groupby(['Partner', 'Direction', 'EventDate'])
        total_direction_groups = len(direction_groups)
        print(f"  {dataset_name}: 计算方向日度分数，共 {total_direction_groups} 组", flush=True)
        
        for i, ((partner, direction, date), group) in enumerate(direction_groups, 1):
            if i % 20000 == 0:  # 降低打印频率
                print(f"  {dataset_name}: 方向日度进度: {i}/{total_direction_groups}", flush=True)
            
            daily_score = self.calculate_daily_weighted_score(group['Score'])
            if not np.isnan(daily_score):
                direction_daily_results.append({
                    'Partner': partner, 'Direction': direction, 'Date': date,
                    'YearMonth': date.strftime('%Y-%m'), 'DailyScore': daily_score
                })
        
        # 2. 为汇总（Aggregated）单独计算每日平均
        aggregated_daily_results = []
        aggregated_groups = df_work.groupby(['Partner', 'EventDate'])
        total_aggregated_groups = len(aggregated_groups)
        print(f"  {dataset_name}: 计算Aggregated日度分数，共 {total_aggregated_groups} 组", flush=True)
        
        for i, ((partner, date), group) in enumerate(aggregated_groups, 1):
            if i % 20000 == 0:
                print(f"  {dataset_name}: Aggregated日度进度: {i}/{total_aggregated_groups}", flush=True)
            
            daily_score = self.calculate_daily_weighted_score(group['Score'])
            if not np.isnan(daily_score):
                aggregated_daily_results.append({
                    'Partner': partner, 'Direction': 'Aggregated', 'Date': date,
                    'YearMonth': date.strftime('%Y-%m'), 'DailyScore': daily_score
                })
        
        # 合并
        daily_frames = []
        if direction_daily_results:
            daily_frames.append(pd.DataFrame(direction_daily_results))
        if aggregated_daily_results:
            daily_frames.append(pd.DataFrame(aggregated_daily_results))
            
        if not daily_frames:
            print(f"  {dataset_name}: 没有有效的日加权分数", flush=True)
            return pd.DataFrame()
            
        daily_df = pd.concat(daily_frames, ignore_index=True)
        print(f"  {dataset_name}: 日度计算完成，共 {len(daily_df)} 条", flush=True)
        
        # 3. 计算月度指数
        monthly_results = []
        monthly_groups = daily_df.groupby(['Partner', 'Direction', 'YearMonth'])
        
        for (partner, direction, month), group in monthly_groups:
            monthly_score = group['DailyScore'].mean()
            if not np.isnan(monthly_score):
                monthly_results.append({
                    'Partner': partner, 'Index_Type': direction,
                    'YearMonth': month, 'Index_Value': monthly_score
                })
        
        result_df = pd.DataFrame(monthly_results)
        print(f"  {dataset_name}: 月度指数计算完成，共 {len(result_df)} 条", flush=True)
        return result_df
    
    def create_complete_time_series(self, monthly_df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        """创建完整的时间序列"""
        if monthly_df.empty:
            print(f"  {dataset_name}: 月度指数数据为空，跳过插值", flush=True)
            return pd.DataFrame()
        
        print(f"  {dataset_name}: 开始创建完整时间序列...", flush=True)
        
        dates = pd.period_range(start=Config.START_DATE, end=Config.END_DATE, freq='M')
        all_months = [str(p) for p in dates]
        all_partners = monthly_df['Partner'].unique()
        all_index_types = monthly_df['Index_Type'].unique()
        
        complete_data = []
        for partner in all_partners:
            for index_type in all_index_types:
                mask = (monthly_df['Partner'] == partner) & (monthly_df['Index_Type'] == index_type)
                partner_data = monthly_df[mask].copy()
                if partner_data.empty: continue
                
                time_series = pd.Series(index=all_months, dtype=float)
                for _, row in partner_data.iterrows():
                    time_series[row['YearMonth']] = row['Index_Value']
                
                time_series_interpolated = self._linear_interpolation(time_series)
                
                for month, value in time_series_interpolated.items():
                    complete_data.append({
                        'Partner': partner, 'Index_Type': index_type,
                        'YearMonth': month, 'Index_Value': value
                    })
        
        result_df = pd.DataFrame(complete_data)
        print(f"  {dataset_name}: 完整时间序列创建完成", flush=True)
        return result_df
    
    def _linear_interpolation(self, series: pd.Series) -> pd.Series:
        """
        对时间序列应用线性插值（仅插中间，首尾留空）
        """
        if series.isna().all():
            return series
        
        temp_series = series.copy()
        temp_series.index = pd.to_datetime(temp_series.index, format='%Y-%m')
        
        # 使用Pandas标准线性插值
        temp_series_interpolated = temp_series.interpolate(method='linear')
        
        temp_series_interpolated.index = temp_series_interpolated.index.strftime('%Y-%m')
        return temp_series_interpolated


# ==================== 并行计算函数 ====================
def compute_single_lambda(args: Tuple[float, pd.DataFrame, pd.DataFrame]) -> Tuple[float, pd.DataFrame, pd.DataFrame]:
    lambda_val, gdelt_data, icews_data = args
    
    try:
        print(f"[子进程] 开始计算 λ={lambda_val}", flush=True)
        calculator = PoliticalRelationIndexCalculator(lambda_val)
        
        gdelt_monthly = calculator.calculate_monthly_index(gdelt_data, f"GDELT(λ={lambda_val})")
        gdelt_results = calculator.create_complete_time_series(gdelt_monthly, f"GDELT(λ={lambda_val})")
        
        icews_monthly = calculator.calculate_monthly_index(icews_data, f"ICEWS(λ={lambda_val})")
        icews_results = calculator.create_complete_time_series(icews_monthly, f"ICEWS(λ={lambda_val})")
        
        if not gdelt_results.empty: gdelt_results['Lambda'] = lambda_val
        if not icews_results.empty: icews_results['Lambda'] = lambda_val
        
        print(f"[子进程] ✓ λ={lambda_val} 计算完成", flush=True)
        return lambda_val, gdelt_results, icews_results
        
    except Exception as e:
        print(f"[子进程] ✗ λ={lambda_val} 计算失败: {e}", flush=True)
        traceback.print_exc()
        return lambda_val, pd.DataFrame(), pd.DataFrame()


# ==================== 并行计算管理器 ====================
class ParallelComputeManager:
    """并行计算管理器"""
    
    def __init__(self):
        self.gdelt_data = None
        self.icews_data = None
        
    def load_all_data(self):
        print("开始加载数据...", flush=True)
        self.gdelt_data = DataLoader.load_gdelt_data(Config.GDELT_PATH)
        self.icews_data = DataLoader.load_icews_data(Config.ICEWS_PATH)
        print("数据加载完成", flush=True)
    
    def compute_all_lambdas_parallel(self) -> Dict[float, Tuple[pd.DataFrame, pd.DataFrame]]:
        print(f"\n{'='*60}", flush=True)
        print(f"开始并行计算 {len(Config.LAMBDA_VALUES)} 个λ值", flush=True)
        print(f"使用进程数: {Config.MAX_PROCESSES}", flush=True)
        print(f"{'='*60}", flush=True)
        
        tasks = [(lam, self.gdelt_data.copy(), self.icews_data.copy()) for lam in Config.LAMBDA_VALUES]
        results = {}
        
        with Pool(processes=Config.MAX_PROCESSES) as pool:
            total_tasks = len(tasks)
            print(f"启动并行计算，共 {total_tasks} 个任务...", flush=True)
            
            for i, (lambda_val, gdelt_results, icews_results) in enumerate(pool.imap_unordered(compute_single_lambda, tasks, chunksize=1), 1):
                results[lambda_val] = (gdelt_results, icews_results)
                print(f"主进程进度: {i}/{total_tasks} ({i/total_tasks*100:.1f}%)", flush=True)
        
        print(f"\n所有λ值计算完成", flush=True)
        return results

# ==================== 串行计算管理器（调试用） ====================
class SerialComputeManager(ParallelComputeManager):
    def compute_all_lambdas(self) -> Dict[float, Tuple[pd.DataFrame, pd.DataFrame]]:
        print(f"\n{'='*60}", flush=True)
        print(f"开始串行计算（调试模式）", flush=True)
        print(f"{'='*60}", flush=True)
        results = {}
        for lam in Config.LAMBDA_VALUES:
            try:
                lambda_val, gdelt_df, icews_df = self.compute_for_lambda(lam)
                results[lambda_val] = (gdelt_df, icews_df)
            except Exception as e:
                print(f"λ={lam} 计算失败: {e}", flush=True)
                traceback.print_exc()
                results[lam] = (pd.DataFrame(), pd.DataFrame())
        return results
    
    def compute_for_lambda(self, lambda_val: float) -> Tuple[float, pd.DataFrame, pd.DataFrame]:
        print(f"\n开始计算 λ={lambda_val}", flush=True)
        calculator = PoliticalRelationIndexCalculator(lambda_val)
        
        print(f"\n计算GDELT数据:", flush=True)
        gdelt_monthly = calculator.calculate_monthly_index(self.gdelt_data, "GDELT")
        gdelt_results = calculator.create_complete_time_series(gdelt_monthly, "GDELT")
        
        print(f"\n计算ICEWS数据:", flush=True)
        icews_monthly = calculator.calculate_monthly_index(self.icews_data, "ICEWS")
        icews_results = calculator.create_complete_time_series(icews_monthly, "ICEWS")
        
        if not gdelt_results.empty: gdelt_results['Lambda'] = lambda_val
        if not icews_results.empty: icews_results['Lambda'] = lambda_val
        
        print(f"\nλ={lambda_val} 计算完成", flush=True)
        return lambda_val, gdelt_results, icews_results

# ... (相关性分析和结果输出部分保持不变，为了节省篇幅这里省略，你需要把原来的CorrelationAnalyzer和ResultExporter类加回来) ...
# ==================== 相关性分析 (原样保留) ====================
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
            print(f"相关性计算失败: {e}", flush=True)
            return {
                'pearson_r': np.nan,
                'pearson_p': np.nan,
                'spearman_r': np.nan,
                'spearman_p': np.nan
            }
    
    @staticmethod
    def analyze_all_correlations(gdelt_results: Dict[float, pd.DataFrame], 
                               icews_results: Dict[float, pd.DataFrame]) -> pd.DataFrame:
        """分析所有相关性"""
        print("\n开始相关性分析...", flush=True)
        
        all_correlations = []
        
        # 获取所有目标国家
        target_countries = Config.TARGET_COUNTRIES
        index_types = Config.INDEX_TYPES
        
        print(f"分析配置:", flush=True)
        print(f"  目标国家数: {len(target_countries)}", flush=True)
        print(f"  指数类型数: {len(index_types)}", flush=True)
        print(f"  λ值数量: {len(Config.LAMBDA_VALUES)}", flush=True)
        
        total_combinations = len(target_countries) * len(index_types) * len(Config.LAMBDA_VALUES)
        current_combination = 0
        
        for partner in target_countries:
            for index_type in index_types:
                for lambda_val in Config.LAMBDA_VALUES:
                    current_combination += 1
                    
                    if current_combination % 500 == 0:
                        print(f"  进度: {current_combination}/{total_combinations}", flush=True)
                    
                    # 获取对应数据
                    gdelt_df = gdelt_results.get(lambda_val, pd.DataFrame())
                    icews_df = icews_results.get(lambda_val, pd.DataFrame())
                    
                    if gdelt_df.empty or icews_df.empty:
                        continue
                    
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
                        'Lambda': lambda_val,
                        'Pearson_r': corr_result['pearson_r'],
                        'Pearson_p': corr_result['pearson_p'],
                        'Spearman_r': corr_result['spearman_r'],
                        'Spearman_p': corr_result['spearman_p']
                    })
        
        result_df = pd.DataFrame(all_correlations)
        print(f"\n相关性分析完成，共 {len(result_df)} 条有效记录", flush=True)
        
        return result_df
    
    @staticmethod
    def find_best_lambdas(correlations_df: pd.DataFrame) -> pd.DataFrame:
        """为每个(Partner, Index_Type)组合寻找最优lambda"""
        print("\n寻找最优λ值...", flush=True)
        
        best_results = []
        
        for partner in correlations_df['Partner'].unique():
            for index_type in correlations_df['Index_Type'].unique():
                mask = (correlations_df['Partner'] == partner) & (correlations_df['Index_Type'] == index_type)
                subset = correlations_df[mask].copy()
                
                if subset.empty:
                    continue
                
                # 方案一：优先选择斯皮尔曼相关系数最高且显著的λ
                # 筛选显著的结果
                significant_mask = subset['Spearman_p'] < Config.SIGNIFICANCE_LEVEL
                significant_subset = subset[significant_mask]
                
                if not significant_subset.empty:
                    # 选择绝对值最大的
                    best_idx = significant_subset['Spearman_r'].abs().idxmax()
                    best_row = significant_subset.loc[best_idx]
                    selection_method = "斯皮尔曼显著最优"
                else:
                    # 没有显著结果，选择斯皮尔曼绝对值最大的
                    best_idx = subset['Spearman_r'].abs().idxmax()
                    best_row = subset.loc[best_idx]
                    selection_method = "斯皮尔曼最优（不显著）"
                
                best_results.append({
                    'Partner': partner,
                    'Index_Type': index_type,
                    'Best_Lambda': best_row['Lambda'],
                    'Best_Spearman_r': best_row['Spearman_r'],
                    'Best_Spearman_p': best_row['Spearman_p'],
                    'Best_Pearson_r': best_row['Pearson_r'],
                    'Best_Pearson_p': best_row['Pearson_p'],
                    'Selection_Method': selection_method
                })
        
        result_df = pd.DataFrame(best_results)
        print(f"最优λ值寻找完成，共 {len(result_df)} 条记录", flush=True)
        
        return result_df

# ==================== 结果输出 (原样保留) ====================
class ResultExporter:
    """结果输出器"""
    
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def export_monthly_indices(self, gdelt_results: Dict[float, pd.DataFrame], 
                             icews_results: Dict[float, pd.DataFrame]):
        """导出月度指数"""
        print("\n导出月度指数...", flush=True)
        
        # 导出GDELT结果
        gdelt_combined = self._combine_results_by_lambda(gdelt_results, "GDELT")
        if not gdelt_combined.empty:
            gdelt_path = self.output_dir / "GDELT_月度政治关系指数_λ_0-20_并行版.csv"
            gdelt_combined.to_csv(gdelt_path, index=False, encoding='utf-8-sig')
            print(f"GDELT指数已保存: {gdelt_path}", flush=True)
        else:
            print("警告: GDELT结果为空，跳过保存", flush=True)
        
        # 导出ICEWS结果
        icews_combined = self._combine_results_by_lambda(icews_results, "ICEWS")
        if not icews_combined.empty:
            icews_path = self.output_dir / "ICEWS_月度政治关系指数_λ_0-20_并行版.csv"
            icews_combined.to_csv(icews_path, index=False, encoding='utf-8-sig')
            print(f"ICEWS指数已保存: {icews_path}", flush=True)
        else:
            print("警告: ICEWS结果为空，跳过保存", flush=True)
    
    def _combine_results_by_lambda(self, results_dict: Dict[float, pd.DataFrame], 
                                 dataset_name: str) -> pd.DataFrame:
        """按lambda合并结果"""
        all_data = []
        
        for lambda_val, df in results_dict.items():
            if df.empty:
                continue
            
            # 复制并添加lambda标记
            df_copy = df.copy()
            # 修改列名格式，保留一位小数
            df_copy[f'Index_lambda_{lambda_val:.1f}'] = df_copy['Index_Value']
            
            # 只保留必要的列
            keep_cols = ['Partner', 'Index_Type', 'YearMonth', f'Index_lambda_{lambda_val:.1f}']
            df_copy = df_copy[keep_cols]
            
            all_data.append(df_copy)
        
        if not all_data:
            return pd.DataFrame()
        
        # 合并所有lambda的结果
        combined = all_data[0]
        for df in all_data[1:]:
            combined = pd.merge(combined, df, on=['Partner', 'Index_Type', 'YearMonth'], how='outer')
        
        return combined
    
    def export_correlation_analysis(self, correlations_df: pd.DataFrame):
        """导出相关性分析结果"""
        print("\n导出相关性分析结果...", flush=True)
        
        if correlations_df.empty:
            print("警告: 相关性分析结果为空，跳过保存", flush=True)
            return pd.DataFrame()
        
        # 标记最优斯皮尔曼相关系数
        correlations_df['Is_Best_Spearman'] = False
        
        for partner in correlations_df['Partner'].unique():
            for index_type in correlations_df['Index_Type'].unique():
                mask = (correlations_df['Partner'] == partner) & (correlations_df['Index_Type'] == index_type)
                subset = correlations_df[mask]
                
                if subset.empty:
                    continue
                
                # 筛选显著的结果
                significant_mask = subset['Spearman_p'] < Config.SIGNIFICANCE_LEVEL
                significant_subset = subset[significant_mask]
                
                if not significant_subset.empty:
                    # 找到显著的斯皮尔曼绝对值最大的行
                    best_idx = significant_subset['Spearman_r'].abs().idxmax()
                    correlations_df.loc[best_idx, 'Is_Best_Spearman'] = True
                else:
                    # 没有显著结果，选择斯皮尔曼绝对值最大的
                    best_idx = subset['Spearman_r'].abs().idxmax()
                    correlations_df.loc[best_idx, 'Is_Best_Spearman'] = True
        
        # 保存结果
        corr_path = self.output_dir / "GDELT_ICEWS_相关性分析_详细结果_λ_0-20_并行版.csv"
        correlations_df.to_csv(corr_path, index=False, encoding='utf-8-sig')
        print(f"相关性分析结果已保存: {corr_path}", flush=True)
        
        best_count = correlations_df['Is_Best_Spearman'].sum()
        print(f"标记为最优斯皮尔曼的记录数: {best_count}", flush=True)
        
        return correlations_df
    
    def export_best_lambda_summary(self, best_lambda_df: pd.DataFrame):
        """导出最优lambda汇总结果"""
        print("\n导出最优λ汇总结果...", flush=True)
        
        if best_lambda_df.empty:
            print("警告: 最优λ汇总结果为空，跳过保存", flush=True)
            return
        
        best_path = self.output_dir / "GDELT_ICEWS_最优λ结果汇总_λ_0-20_并行版.csv"
        best_lambda_df.to_csv(best_path, index=False, encoding='utf-8-sig')
        print(f"最优λ汇总结果已保存: {best_path}", flush=True)
        
        # 显示λ值分布
        print("\n最优λ值分布:", flush=True)
        lambda_counts = best_lambda_df['Best_Lambda'].value_counts().sort_index()
        for lam, count in lambda_counts.items():
            print(f"  λ={lam}: {count} 个队列", flush=True)

# ==================== 主程序 ====================
def main():
    """主程序"""
    print("=" * 80, flush=True)
    print("中国与25国双边政治关系指数计算系统", flush=True)
    print("=" * 80, flush=True)
    
    output_dir = Path(Config.OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 【重要】调试阶段：请先把下面这行改成 SerialComputeManager() 并把 Config.LAMBDA_VALUES 改成 [0]
    manager = ParallelComputeManager() 
    exporter = ResultExporter(Config.OUTPUT_DIR)
    
    try:
        manager.load_all_data()
        
        if manager.gdelt_data is None or manager.gdelt_data.empty:
            print("错误: GDELT数据为空!", flush=True)
            return
        if manager.icews_data is None or manager.icews_data.empty:
            print("错误: ICEWS数据为空!", flush=True)
            return
        
        # 选择计算方式
        if isinstance(manager, SerialComputeManager):
            all_results = manager.compute_all_lambdas()
        else:
            all_results = manager.compute_all_lambdas_parallel()
            
        gdelt_results = {lam: gdelt_df for lam, (gdelt_df, _) in all_results.items()}
        icews_results = {lam: icews_df for lam, (_, icews_df) in all_results.items()}
        
        exporter.export_monthly_indices(gdelt_results, icews_results)
        
        correlations_df = CorrelationAnalyzer.analyze_all_correlations(gdelt_results, icews_results)
        if not correlations_df.empty:
            correlations_df = exporter.export_correlation_analysis(correlations_df)
            best_lambda_df = CorrelationAnalyzer.find_best_lambdas(correlations_df)
            exporter.export_best_lambda_summary(best_lambda_df)
        
        print("\n计算完成！", flush=True)
        
    except Exception as e:
        print(f"\n程序执行出错: {e}", flush=True)
        traceback.print_exc()

if __name__ == "__main__":
    if os.name == 'nt':
        from multiprocessing import set_start_method
        try:
            set_start_method('spawn')
        except RuntimeError:
            pass
    main()
