import os
import sys
import logging
import pandas as pd
from datetime import datetime
from typing import List, Dict, Optional
import time
import requests
import zipfile

# 尝试导入pyDataverse
try:
    from pyDataverse.api import NativeApi
except ImportError:
    print("错误：未安装pyDataverse库")
    print("请运行以下命令安装：pip install pyDataverse")
    sys.exit(1)

# ==================== 终端输出保存类 ====================
class Tee:
    """同时输出到控制台和文件的类"""
    def __init__(self, *files):
        self.files = files
    
    def write(self, obj):
        for f in self.files:
            f.write(obj)
            f.flush()  # 确保立即写入
    
    def flush(self):
        for f in self.files:
            f.flush()

def setup_output_saving():
    """设置终端输出保存"""
    # 输出目录
    output_dir = r"C:\Users\胡克劳\Desktop\ICEWS\终端文案输出"
    os.makedirs(output_dir, exist_ok=True)
    
    # 生成文件名：当前时间+中国与25国双边政治事件检索
    current_time = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{current_time}_中国与25国双边政治事件检索记录4.21.txt"
    filepath = os.path.join(output_dir, filename)
    
    # 打开文件
    log_file = open(filepath, 'w', encoding='utf-8')
    
    # 保存原始stdout
    original_stdout = sys.stdout
    
    # 重定向输出
    sys.stdout = Tee(sys.stdout, log_file)
    
    print(f"终端输出已保存到: {filepath}")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)
    
    return original_stdout, log_file, filepath

# ==================== 配置区域 ====================
class Config:
    """配置类"""
    
    # Dataverse API配置
    API_KEY = "4ab0719b-5d23-4c58-9524-8bb70553bcd6"
    BASE_URL = "https://dataverse.harvard.edu"
    
    # 数据集配置
    ICEWS_DATASET_DOI = "doi:10.7910/DVN/28075"  # ICEWS数据集（CAMEO编码）
    
    # 时间范围
    START_DATE = "2002-01-01"
    END_DATE = "2023-04-10"
    
    # 目标国家列表（中国+25个贸易伙伴国）
    CHINA = "China"
    TRADE_PARTNERS = [
        "Japan", "United States", "South Korea", "Germany", "Malaysia",
        "Singapore", "Russia", "United Kingdom", "Netherlands", "Australia",
        "Italy", "Thailand", "France", "Indonesia", "Canada",
        "Philippines", "Saudi Arabia", "India", "Belgium", "Brazil",
        "Mexico", "United Arab Emirates", "Spain", "Vietnam", "Iran"
    ]
    ALL_COUNTRIES = [CHINA] + TRADE_PARTNERS
    
    # 输出配置
    OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\ICEWS"
    OUTPUT_FILENAME = f"ICEWS_中国与25国双边政治事件_{START_DATE}_to_{END_DATE}.csv"
    
    # 事件编码文件路径
    CAMEO_CODES_FILE = os.path.join(OUTPUT_DIR, "ICEWS_CAMEO_事件编码体系完整表.csv")
    
    # 网络请求配置
    MAX_RETRIES = 5
    REQUEST_TIMEOUT = 120
    BASE_DELAY = 3
    MAX_DELAY = 30
    
    # 目标列名顺序（已移除「编码」列，严格按照要求排序）
    TARGET_COLUMNS = [
        'Event ID', 'Event Date', 'Source Name', 'Source Sectors', 
        'Source Country', 'Event Text', 'CAMEO Code', 'Intensity', 
        'Target Name', 'Target Sectors', 'Target Country', 'Story ID', 
        'Sentence Number', 'Publisher', 'City', 'District', 'Province', 
        'Country', 'Latitude', 'Longitude', '_dataset_source', '_event_direction',
        'ï»¿Event ID', '中文事件描述', '英文事件描述', 'Goldstein分值', 'Quad分类'
    ]

# ==================== 日志配置 ====================
def setup_logging(config: Config) -> logging.Logger:
    """配置日志系统"""
    log_file = os.path.join(config.OUTPUT_DIR, "ICEWS_中国与25国双边政治事件检索日志4.21.log")
    
    os.makedirs(config.OUTPUT_DIR, exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    
    return logging.getLogger(__name__)

# ==================== CAMEO编码加载（优化版：增加校验+格式统一）====================
def load_cameo_codes(file_path: str, logger: logging.Logger) -> pd.DataFrame:
    """加载CAMEO事件编码体系，增加格式校验和异常处理，确保匹配准确性"""
    try:
        logger.info(f"正在加载CAMEO编码文件: {file_path}")
        # 读取编码文件，统一列名格式
        df = pd.read_csv(file_path, encoding='utf-8-sig')
        df.columns = [col.strip() for col in df.columns]
        
        # 校验必填列是否存在
        required_cols = ['编码', '中文事件描述', '英文事件描述', 'Goldstein分值', 'Quad分类']
        missing_cols = [col for col in required_cols if col not in df.columns]
        if missing_cols:
            logger.error(f"CAMEO编码文件缺失必填列: {missing_cols}")
            return pd.DataFrame()
        
        # 统一编码列为数字格式，去除空值
        df['编码'] = pd.to_numeric(df['编码'], errors='coerce')
        df = df.dropna(subset=['编码']).reset_index(drop=True)
        
        logger.info(f"成功加载 {len(df)} 条有效CAMEO编码记录")
        logger.info(f"CAMEO文件列名: {list(df.columns)}")
        return df
    except Exception as e:
        logger.error(f"加载CAMEO编码文件失败: {str(e)}")
        return pd.DataFrame()

# ==================== 网络请求增强 ====================
def create_session(config: Config, logger: logging.Logger) -> requests.Session:
    """创建配置优化的requests会话"""
    session = requests.Session()
    
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry
    
    retry_strategy = Retry(
        total=config.MAX_RETRIES,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["HEAD", "GET", "OPTIONS"]
    )
    
    adapter = HTTPAdapter(
        max_retries=retry_strategy,
        pool_connections=1,
        pool_maxsize=1
    )
    
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    
    session.headers.update({
        "X-Dataverse-key": config.API_KEY,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    })
    
    logger.info("已创建优化的网络会话")
    return session

# ==================== 数据检索器 ====================
class DataRetriever:
    """数据检索器（仅使用ICEWS数据集）"""
    
    def __init__(self, config: Config, logger: logging.Logger):
        self.config = config
        self.logger = logger
        self.api = None
        self.session = None
        self._init_api()
    
    def _init_api(self):
        """初始化API连接"""
        try:
            self.logger.info(f"正在连接Dataverse: {self.config.BASE_URL}")
            self.api = NativeApi(self.config.BASE_URL, self.config.API_KEY)
            self.session = create_session(self.config, self.logger)
            self.logger.info("Dataverse API连接成功")
        except Exception as e:
            self.logger.error(f"Dataverse API连接失败: {str(e)}")
            raise
    
    def get_dataset_files(self, dataset_doi: str, dataset_name: str) -> List[Dict]:
        """获取数据集中的文件列表"""
        try:
            self.logger.info(f"正在获取{dataset_name}数据集文件列表: {dataset_doi}")
            
            dataset = self.api.get_dataset(dataset_doi)
            files = dataset.json()['data']['latestVersion']['files']
            
            self.logger.info(f"{dataset_name}找到 {len(files)} 个文件")
            
            # 打印前5个文件名用于调试
            if files:
                self.logger.info(f"{dataset_name}文件示例:")
                for i, f in enumerate(files[:5], 1):
                    self.logger.info(f"  {i}. {f['dataFile']['filename']}")
            
            return files
            
        except Exception as e:
            self.logger.error(f"获取{dataset_name}数据集文件列表失败: {str(e)}")
            return []
    
    def download_file(self, file_id: int, file_name: str) -> Optional[str]:
        """下载文件"""
        temp_file = os.path.join(self.config.OUTPUT_DIR, f"temp_{file_name}")
        
        download_url = f"{self.config.BASE_URL}/api/access/datafile/{file_id}"
        
        for attempt in range(self.config.MAX_RETRIES):
            try:
                delay = min(self.config.BASE_DELAY * (2 ** attempt), self.config.MAX_DELAY)
                
                if attempt > 0:
                    self.logger.info(f"下载尝试 {attempt + 1}/{self.config.MAX_RETRIES}，等待 {delay} 秒...")
                    time.sleep(delay)
                
                self.logger.info(f"正在下载文件: {file_name} (ID: {file_id})")
                
                response = self.session.get(
                    download_url,
                    stream=True,
                    timeout=self.config.REQUEST_TIMEOUT,
                    verify=True
                )
                response.raise_for_status()
                
                with open(temp_file, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                
                file_size = os.path.getsize(temp_file)
                self.logger.info(f"文件下载完成: {temp_file} (大小: {file_size:,} 字节)")
                
                return temp_file
                
            except requests.exceptions.SSLError as e:
                self.logger.warning(f"SSL错误 (尝试 {attempt + 1}/{self.config.MAX_RETRIES}): {str(e)}")
                if attempt == self.config.MAX_RETRIES - 1:
                    self.logger.error("已达到最大重试次数，SSL错误无法恢复")
                    return None
                
            except requests.exceptions.RequestException as e:
                self.logger.warning(f"网络错误 (尝试 {attempt + 1}/{self.config.MAX_RETRIES}): {str(e)}")
                if attempt == self.config.MAX_RETRIES - 1:
                    self.logger.error("已达到最大重试次数，放弃下载")
                    return None
        
        return None
    
    def extract_zip(self, zip_path: str, file_name: str) -> Optional[str]:
        """解压ZIP文件"""
        if not zipfile.is_zipfile(zip_path):
            self.logger.info(f"文件不是ZIP格式，直接使用: {file_name}")
            return zip_path
        
        try:
            self.logger.info(f"正在解压文件: {file_name}")
            
            extract_dir = os.path.join(self.config.OUTPUT_DIR, "extracted")
            os.makedirs(extract_dir, exist_ok=True)
            
            with zipfile.ZipFile(zip_path, 'r') as zf:
                tab_files = [f for f in zf.namelist() if f.endswith(('.tab', '.tsv', '.csv'))]
                
                if not tab_files:
                    self.logger.warning("ZIP文件中未找到数据文件，尝试解压所有文件")
                    zf.extractall(extract_dir)
                    return extract_dir
                
                target_file = tab_files[0]
                zf.extract(target_file, extract_dir)
                extracted_path = os.path.join(extract_dir, target_file)
                
                self.logger.info(f"解压完成: {extracted_path}")
                return extracted_path
                
        except Exception as e:
            self.logger.error(f"解压失败: {str(e)}")
            return zip_path
    
    def filter_files_by_year(self, files: List[Dict], dataset_name: str) -> List[Dict]:
        """按年份筛选文件"""
        filtered_files = []
        
        start_year = int(self.config.START_DATE.split('-')[0])
        end_year = int(self.config.END_DATE.split('-')[0])
        
        for file in files:
            file_name = file['dataFile']['filename']
            file_label = file.get('label', file_name)
            file_id = file['dataFile']['id']
            
            # 从文件名中提取年份
            import re
            year_match = re.search(r'[._-](20\d{2}|19\d{2})[._-]', file_name)
            year = None
            
            if year_match:
                year = int(year_match.group(1))
            else:
                # 尝试其他模式
                for y in range(start_year, end_year + 1):
                    if str(y) in file_name or str(y) in file_label:
                        year = y
                        break
            
            if year is not None and start_year <= year <= end_year:
                filtered_files.append({
                    'id': file_id,
                    'name': file_name,
                    'label': file_label,
                    'year': year,
                    'dataset': dataset_name
                })
                self.logger.info(f"筛选到文件 ({dataset_name}): {file_name} (年份: {year})")
        
        self.logger.info(f"{dataset_name}共筛选到 {len(filtered_files)} 个待处理文件")
        return filtered_files
    
    def process_data_file(self, file_path: str, dataset_name: str) -> pd.DataFrame:
        """处理数据文件，保留原始列名（不清理BOM），恢复老代码读取逻辑"""
        try:
            self.logger.info(f"正在处理文件 ({dataset_name}): {file_path}")
            
            df = None
            encodings = ['utf-8-sig', 'latin1', 'utf-8', 'cp1252']
            separators = ['\t', ',', '|']
            
            for encoding in encodings:
                for sep in separators:
                    try:
                        df = pd.read_csv(
                            file_path, 
                            sep=sep, 
                            encoding=encoding,
                            low_memory=False,
                            on_bad_lines='skip'
                        )
                        if len(df) > 0 and len(df.columns) > 1:
                            self.logger.info(f"成功读取: encoding={encoding}, sep={repr(sep)}")
                            break
                    except Exception as e:
                        continue
                if df is not None and len(df) > 0:
                    break
            
            if df is None or len(df) == 0:
                self.logger.error("无法解析文件")
                return pd.DataFrame()
            
            # 不清理列名BOM，保留原始列名（包括ï»¿Event ID），仅去除首尾空格
            df.columns = [col.strip() for col in df.columns]
            
            # 添加数据集来源标记
            df['_dataset_source'] = dataset_name
            
            self.logger.info(f"文件包含 {len(df)} 条记录, {len(df.columns)} 列")
            self.logger.info(f"列名: {list(df.columns)}")
            
            return df
            
        except Exception as e:
            self.logger.error(f"处理文件失败: {str(e)}")
            return pd.DataFrame()
    
    def standardize_columns(self, df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        """
        将数据列名统一转换为ICEWS格式，确保目标列都存在
        优化：CAMEO相关列不在此提前创建，避免merge时列名冲突
        """
        if df.empty:
            return df
        
        # ICEWS数据集，直接使用原列名
        column_mapping = {col: col for col in df.columns}
        
        # 重命名列
        df = df.rename(columns=column_mapping)
        
        # 仅提前创建非CAMEO相关的目标列，CAMEO列在merge后补充
        cameo_related_cols = ['中文事件描述', '英文事件描述', 'Goldstein分值', 'Quad分类']
        for col in self.config.TARGET_COLUMNS:
            if col not in df.columns and col not in cameo_related_cols:
                df[col] = None
        
        return df
    
    def filter_bilateral_events(self, df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        """
        筛选中国与25个贸易伙伴国之间的双边事件
        包括两种情况：
        1. 中国 -> 贸易伙伴国
        2. 贸易伙伴国 -> 中国
        """
        if df.empty:
            return df
        
        try:
            self.logger.info(f"正在筛选中国与25个贸易伙伴国的双边事件 ({dataset_name})...")
            
            # 根据数据集选择列名
            source_cols = ['Source Country', 'source_country', 'Actor1CountryCode', 'Actor1Geo_CountryCode']
            target_cols = ['Target Country', 'target_country', 'Actor2CountryCode', 'Actor2Geo_CountryCode']
            
            # 找到可用的列
            source_col = None
            target_col = None
            
            for col in source_cols:
                if col in df.columns:
                    source_col = col
                    break
            
            for col in target_cols:
                if col in df.columns:
                    target_col = col
                    break
            
            if source_col is None or target_col is None:
                self.logger.warning(f"未找到国家列，无法筛选双边事件")
                self.logger.info(f"可用列: {list(df.columns)}")
                return pd.DataFrame()
            
            self.logger.info(f"使用 Source列: {source_col}, Target列: {target_col}")
            
            # 转换为字符串并清洗
            df[source_col] = df[source_col].astype(str).str.strip()
            df[target_col] = df[target_col].astype(str).str.strip()
            
            # 获取中国和贸易伙伴国的名称
            china = self.config.CHINA
            trade_partners = self.config.TRADE_PARTNERS
            
            # 构建筛选条件
            masks = []
            
            # 情况1: 中国 -> 贸易伙伴国
            for partner in trade_partners:
                mask = (
                    df[source_col].str.contains(china, case=False, na=False) &
                    df[target_col].str.contains(partner, case=False, na=False)
                )
                masks.append(mask)
            
            # 情况2: 贸易伙伴国 -> 中国
            for partner in trade_partners:
                mask = (
                    df[source_col].str.contains(partner, case=False, na=False) &
                    df[target_col].str.contains(china, case=False, na=False)
                )
                masks.append(mask)
            
            # 合并所有条件
            if masks:
                combined_mask = masks[0]
                for mask in masks[1:]:
                    combined_mask = combined_mask | mask
            else:
                self.logger.warning("未创建任何筛选条件")
                return pd.DataFrame()
            
            filtered_df = df[combined_mask].copy()
            
            # 添加方向标记
            filtered_df['_event_direction'] = 'Unknown'
            
            # 标记每个事件的方向
            for i, row in filtered_df.iterrows():
                source = row[source_col]
                target = row[target_col]
                
                if china.lower() in source.lower():
                    for partner in trade_partners:
                        if partner.lower() in target.lower():
                            filtered_df.at[i, '_event_direction'] = f'{china} -> {partner}'
                            break
                else:
                    for partner in trade_partners:
                        if partner.lower() in source.lower():
                            filtered_df.at[i, '_event_direction'] = f'{partner} -> {china}'
                            break
            
            self.logger.info(f"筛选后保留 {len(filtered_df)} 条中国与25国的双边事件")
            
            # 显示方向统计
            if len(filtered_df) > 0:
                direction_counts = filtered_df['_event_direction'].value_counts().head(20)  # 显示前20个
                self.logger.info(f"事件方向统计 (前20个):")
                for direction, count in direction_counts.items():
                    self.logger.info(f"  {direction}: {count:,} 条")
            
            return filtered_df
            
        except Exception as e:
            self.logger.error(f"筛选双边事件失败: {str(e)}")
            return pd.DataFrame()
    
    def filter_by_date(self, df: pd.DataFrame, dataset_name: str) -> pd.DataFrame:
        """按日期范围筛选"""
        if df.empty:
            return df
        
        try:
            date_cols = [col for col in df.columns if 'date' in col.lower() or 'time' in col.lower()]
            
            if not date_cols:
                self.logger.warning("未找到日期列，跳过日期筛选")
                return df
            
            date_col = date_cols[0]
            self.logger.info(f"使用日期列: {date_col}")
            
            df[date_col] = pd.to_datetime(df[date_col], errors='coerce')
            
            # 设置日期范围
            start_date = pd.to_datetime(self.config.START_DATE)
            end_date = pd.to_datetime(self.config.END_DATE)
            self.logger.info(f"日期范围: {self.config.START_DATE} 至 {self.config.END_DATE}")
            
            mask = (df[date_col] >= start_date) & (df[date_col] <= end_date)
            filtered_df = df[mask].copy()
            
            self.logger.info(f"日期筛选后保留 {len(filtered_df)} 条记录")
            return filtered_df
            
        except Exception as e:
            self.logger.error(f"日期筛选失败: {str(e)}")
            return df
    
    # ==================== CAMEO合并（完全修复版：解决空值核心bug）====================
    def merge_cameo_codes(self, df: pd.DataFrame, cameo_df: pd.DataFrame) -> pd.DataFrame:
        """
        修复版CAMEO编码合并：
        1. 解决列名重复导致的空值问题
        2. 增加编码清洗逻辑，大幅提升匹配成功率
        3. 合并后自动移除「编码」列
        """
        if df.empty or cameo_df.empty:
            self.logger.warning("数据或CAMEO编码表为空，跳过合并")
            return df
        
        try:
            # 优先匹配CAMEO Code列，兼容其他编码列名
            event_code_cols = [
                'CAMEO Code', 'Event Type', 'Event Code', 
                'cameo_code', 'event_type', 'Quad Code'
            ]
            
            cameo_col = None
            for col in event_code_cols:
                if col in df.columns:
                    cameo_col = col
                    break
            
            if cameo_col is None:
                self.logger.warning("未找到事件编码列，跳过CAMEO编码合并")
                self.logger.info(f"可用编码相关列: {[c for c in df.columns if 'code' in c.lower() or 'event' in c.lower()]}")
                return df
            
            self.logger.info(f"使用事件编码列: {cameo_col}")
            
            # ========== 核心修复1：删除已存在的CAMEO相关列，避免合并时列名冲突 ==========
            drop_cols = ['编码', '中文事件描述', '英文事件描述', 'Goldstein分值', 'Quad分类']
            df = df.drop(columns=[col for col in drop_cols if col in df.columns], errors='ignore')
            
            # ========== 核心修复2：编码清洗，兼容前导零、非数字字符等异常格式 ==========
            # 清洗主数据的编码列
            df[cameo_col] = df[cameo_col].astype(str).str.strip()
            # 仅提取数字部分，去除空格、字母、符号等干扰
            df[cameo_col] = df[cameo_col].str.extract(r'(\d+)', expand=False)
            # 统一转为数字格式，转换失败设为NaN
            df[cameo_col] = pd.to_numeric(df[cameo_col], errors='coerce')
            
            # 确保CAMEO编码表的编码列为数字格式
            cameo_df['编码'] = pd.to_numeric(cameo_df['编码'], errors='coerce')
            cameo_df = cameo_df.dropna(subset=['编码']).reset_index(drop=True)
            
            # ========== 核心修复3：无冲突合并 ==========
            merged_df = pd.merge(
                df,
                cameo_df[['编码', '中文事件描述', '英文事件描述', 'Goldstein分值', 'Quad分类']],
                left_on=cameo_col,
                right_on='编码',
                how='left'
            )
            
            # ========== 核心修复4：移除不需要的「编码」列 ==========
            merged_df = merged_df.drop(columns=['编码'], errors='ignore')
            
            self.logger.info("CAMEO编码合并完成，已移除「编码」列")
            # 打印匹配统计
            match_count = merged_df['中文事件描述'].notna().sum()
            total_count = len(merged_df)
            self.logger.info(f"CAMEO编码匹配成功: {match_count:,} 条，匹配成功率: {match_count/total_count*100:.2f}%")
            
            return merged_df
            
        except Exception as e:
            self.logger.error(f"合并CAMEO编码失败: {str(e)}")
            return df
    
    def process_dataset(self, dataset_doi: str, dataset_name: str, cameo_df: pd.DataFrame) -> pd.DataFrame:
        """处理单个数据集，不提前合并CAMEO"""
        all_data = []
        
        self.logger.info(f"{'='*60}")
        self.logger.info(f"开始处理 {dataset_name} 数据集")
        self.logger.info(f"{'='*60}")
        
        files = self.get_dataset_files(dataset_doi, dataset_name)
        if not files:
            self.logger.warning(f"{dataset_name} 未获取到文件")
            return pd.DataFrame()
        
        filtered_files = self.filter_files_by_year(files, dataset_name)
        
        if not filtered_files:
            self.logger.warning(f"{dataset_name} 没有筛选到符合条件的文件")
            return pd.DataFrame()
        
        for i, file_info in enumerate(filtered_files, 1):
            self.logger.info(f"处理进度 ({dataset_name}): {i}/{len(filtered_files)}")
            
            file_id = file_info['id']
            file_name = file_info['name']
            
            try:
                temp_file = self.download_file(file_id, file_name)
                
                if temp_file is None:
                    self.logger.error(f"文件下载失败，跳过: {file_name}")
                    time.sleep(self.config.MAX_DELAY)
                    continue
                
                data_file = self.extract_zip(temp_file, file_name)
                df = self.process_data_file(data_file, dataset_name)
                
                if not df.empty:
                    # 筛选中国与25个贸易伙伴国的双边事件
                    df = self.filter_bilateral_events(df, dataset_name)
                    
                    if not df.empty:
                        # 再筛选日期
                        df = self.filter_by_date(df, dataset_name)
                        
                        if not df.empty:
                            # 统一列名
                            df = self.standardize_columns(df, dataset_name)
                            all_data.append(df)
                
                # 清理临时文件
                if os.path.exists(temp_file) and temp_file != data_file:
                    os.remove(temp_file)
                
                time.sleep(self.config.BASE_DELAY)
                
            except Exception as e:
                self.logger.error(f"处理文件 {file_name} 时出错: {str(e)}")
                continue
        
        if all_data:
            dataset_df = pd.concat(all_data, ignore_index=True)
            self.logger.info(f"{dataset_name} 合并后共 {len(dataset_df)} 条记录")
            return dataset_df
        else:
            self.logger.warning(f"{dataset_name} 未获取到任何数据")
            return pd.DataFrame()
    
    # ==================== 检索所有数据 ====================
    def retrieve_all_data(self, cameo_df: pd.DataFrame) -> pd.DataFrame:
        """检索所有数据"""
        all_data = []
        
        # 处理ICEWS数据集
        self.logger.info("\n" + "="*60)
        self.logger.info("开始处理ICEWS数据集")
        self.logger.info("="*60)
        icews_df = self.process_dataset(self.config.ICEWS_DATASET_DOI, "ICEWS", cameo_df)
        if not icews_df.empty:
            all_data.append(icews_df)
        
        if all_data:
            final_df = pd.concat(all_data, ignore_index=True)
            self.logger.info(f"\n{'='*60}")
            self.logger.info(f"全部数据合并后共 {len(final_df)} 条记录")
            self.logger.info(f"{'='*60}")
            
            # 统一做CAMEO编码匹配
            final_df = self.merge_cameo_codes(final_df, cameo_df)
            
            # 将_event_direction内容填充到ï»¿Event ID列
            self.logger.info("将_event_direction内容填充到ï»¿Event ID列")
            final_df['ï»¿Event ID'] = final_df['_event_direction']
            
            # 严格按照目标列顺序重新排列
            self.logger.info("按照指定顺序重新排列列...")
            
            # 确保所有目标列都存在，缺失的列留空
            for col in self.config.TARGET_COLUMNS:
                if col not in final_df.columns:
                    final_df[col] = None
            
            # 重新排列列，严格遵循指定顺序
            final_df = final_df[self.config.TARGET_COLUMNS].copy()
            
            self.logger.info(f"最终列顺序: {list(final_df.columns)}")
            
            return final_df
        else:
            self.logger.warning("未获取到任何数据")
            return pd.DataFrame()

# ==================== 主函数 ====================
def main():
    """主函数"""
    # 设置终端输出保存
    original_stdout, log_file, output_txt_path = setup_output_saving()
    
    try:
        print("=" * 60)
        print("ICEWS 中国与25国双边政治事件检索工具")
        print("=" * 60)
        print("\n说明：")
        print("- 时间范围: 2002-01-01 至 2023-04-10")
        print("- 数据集: ICEWS (CAMEO编码)")
        print(f"- 目标国家: 中国 + 25个贸易伙伴国")
        print(f"- 贸易伙伴国列表: {', '.join(Config.TRADE_PARTNERS[:5])}...等25国")
        print("- 核心功能: 检索中国与25国的双边政治事件")
        print("- 输出文件: 将保存到桌面ICEWS文件夹")
        print("- 终端输出已自动保存到txt文件")
        print("=" * 60)
        
        config = Config()
        logger = setup_logging(config)
        
        # 打印25个贸易伙伴国完整列表
        print(f"\n完整的25个贸易伙伴国列表:")
        for i, country in enumerate(config.TRADE_PARTNERS, 1):
            print(f"  {i:2d}. {country}")
        print()
        
        # 加载CAMEO编码表
        cameo_df = load_cameo_codes(config.CAMEO_CODES_FILE, logger)
        if cameo_df.empty:
            print("错误：CAMEO编码文件加载失败，请检查文件路径和格式")
            sys.exit(1)
        
        # 初始化检索器
        retriever = DataRetriever(config, logger)
        
        # 开始数据检索
        logger.info("开始数据检索...")
        result_df = retriever.retrieve_all_data(cameo_df)
        
        if not result_df.empty:
            output_file = os.path.join(config.OUTPUT_DIR, config.OUTPUT_FILENAME)
            logger.info(f"正在保存结果到: {output_file}")
            
            # 使用utf-8-sig编码保存，Excel打开中文不会乱码
            result_df.to_csv(output_file, index=False, encoding='utf-8-sig')
            
            logger.info(f"成功保存 {len(result_df)} 条记录")
            print(f"\n处理完成！结果已保存到:")
            print(output_file)
            
            # 显示详细统计
            print(f"\n{'='*60}")
            print("数据统计摘要")
            print(f"{'='*60}")
            print(f"总记录数: {len(result_df):,} 条")
            print(f"总列数: {len(result_df.columns)} 列")
            
            if '_dataset_source' in result_df.columns:
                source_counts = result_df['_dataset_source'].value_counts()
                print(f"\n数据来源:")
                for source, count in source_counts.items():
                    print(f"  {source}: {count:,} 条")
            
            if '_event_direction' in result_df.columns:
                # 统计前10个最活跃的双边关系
                direction_counts = result_df['_event_direction'].value_counts()
                print(f"\n事件方向统计 (前10个):")
                for i, (direction, count) in enumerate(direction_counts.head(10).items(), 1):
                    print(f"  {i:2d}. {direction}: {count:,} 条")
                
                # 按国家统计
                print(f"\n按国家统计:")
                country_stats = {}
                for direction, count in direction_counts.items():
                    countries = direction.split(' -> ')
                    for country in countries:
                        if country not in ['China', 'Unknown']:
                            if country not in country_stats:
                                country_stats[country] = 0
                            country_stats[country] += count
                
                # 按事件数量排序
                sorted_stats = sorted(country_stats.items(), key=lambda x: x[1], reverse=True)
                for i, (country, count) in enumerate(sorted_stats[:10], 1):
                    print(f"  {i:2d}. {country}: {count:,} 条")
            
            # CAMEO匹配统计
            if '中文事件描述' in result_df.columns:
                match_count = result_df['中文事件描述'].notna().sum()
                total_count = len(result_df)
                print(f"\nCAMEO编码匹配统计:")
                print(f"  匹配成功: {match_count:,} 条")
                print(f"  匹配成功率: {match_count/total_count*100:.2f}%")
            
            print(f"\n前5条记录预览:")
            print(result_df.head().to_string())
            print(f"{'='*60}")
            print(f"\n结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"终端输出已保存到: {output_txt_path}")
        else:
            logger.warning("未获取到任何数据")
            print("\n未获取到任何数据，请检查配置和筛选条件")
    
    except Exception as e:
        logger.error(f"程序运行出错: {str(e)}")
        print(f"\n程序运行出错: {str(e)}")
        print("请查看日志文件获取详细信息")
        sys.exit(1)
    finally:
        # 恢复原始stdout并关闭文件
        sys.stdout = original_stdout
        log_file.close()

if __name__ == "__main__":
    main()
