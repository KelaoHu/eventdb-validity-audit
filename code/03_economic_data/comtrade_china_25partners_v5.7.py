import requests
import pandas as pd
import time
import os
import logging
from datetime import datetime

# ========================== 配置区域 ==========================
API_KEY = os.environ.get("COMTRADE_API_KEY", "")  #（在 comtrade.un.org 免费注册申请）
REPORTER_CODE = 156  # 中国UN Comtrade代码

# 目标国家列表 (名称, UN代码)
COUNTRY_LIST = [
    ("Japan", 392), ("United States", 842), ("South Korea", 410),
    ("Germany", 276), ("Malaysia", 458), ("Singapore", 702),
    ("Russia", 643), ("United Kingdom", 826), ("Netherlands", 528),
    ("Australia", 36), ("Italy", 380), ("Thailand", 764),
    ("France", 250), ("Indonesia", 360), ("Canada", 124),
    ("Philippines", 608), ("Saudi Arabia", 682), ("India", 356),
    ("Belgium", 56), ("Brazil", 76), ("Mexico", 484),
    ("United Arab Emirates", 784), ("Iran", 364), ("Spain", 724),
    ("Vietnam", 704)
]

# 时间范围
START_YEAR = 2002
END_YEAR = 2025

# 输出路径配置
OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\经济数据库\Comtrade"
LOG_DIR = os.path.join(OUTPUT_DIR, "检索日志记录")
CSV_FILENAME = "China_25partners_monthly_trade_200201_202512.csv"
LOG_FILENAME = "comtrade_download_log.txt"

# API配置
API_BASE_URL = "https://comtradeapi.un.org/data/v1/get/C/M/HS"
MAX_RETRIES = 3  # 最大重试次数
RETRY_DELAY = 5  # 重试延迟(秒)
REQUEST_DELAY = 2  # 请求间隔(秒)
# ===============================================================


def setup_logging():
    """配置日志系统"""
    os.makedirs(LOG_DIR, exist_ok=True)
    log_path = os.path.join(LOG_DIR, LOG_FILENAME)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_path, encoding='utf-8'),
            logging.StreamHandler()
        ]
    )
    return logging.getLogger(__name__)


def generate_monthly_periods():
    """生成月度时间段列表（按年份分块）"""
    periods = []
    for year in range(START_YEAR, END_YEAR + 1):
        year_periods = [f"{year}{month:02d}" for month in range(1, 13)]
        periods.append(year_periods)
    return periods


def fetch_api_data(logger, partner_code, periods):
    """调用UN Comtrade API获取数据（含重试机制）"""
    params = {
        "reporterCode": REPORTER_CODE,
        "partnerCode": partner_code,
        "period": ",".join(periods),
        "cmdCode": "TOTAL",
        "flowCode": "1,2",  # 1=进口(CIF), 2=出口(FOB)
        "includeDesc": "true",
        "key": API_KEY
    }

    for attempt in range(MAX_RETRIES):
        try:
            logger.info(f"请求数据: 伙伴国={partner_code}, 时间段={periods[0]}-{periods[-1]}")
            response = requests.get(API_BASE_URL, params=params, timeout=60)
            response.raise_for_status()
            
            data = response.json()
            if "data" in data and data["data"]:
                return pd.DataFrame(data["data"])
            else:
                logger.warning(f"无数据返回: 伙伴国={partner_code}, 时间段={periods[0]}-{periods[-1]}")
                return pd.DataFrame()

        except requests.exceptions.RequestException as e:
            logger.error(f"请求失败 (尝试 {attempt+1}/{MAX_RETRIES}): {str(e)}")
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAY)
            else:
                logger.error(f"达到最大重试次数，放弃当前请求")
                return pd.DataFrame()


def process_data(raw_df, country_name_map):
    """数据清洗与格式化"""
    if raw_df.empty:
        return pd.DataFrame()

    # 1. 标准化列名并选择必要字段
    df = raw_df.rename(columns={
        "yr": "year",
        "period": "period",
        "reporterCode": "reporter_code",
        "reporterDesc": "reporter_name",
        "partnerCode": "partner_code",
        "flowCode": "flow_code",
        "flowDesc": "flow_name",
        "cmdCode": "cmd_code",
        "cmdDesc": "cmd_name",
        "primaryValue": "trade_value_usd"
    })

    # 2. 统一国家名称
    df["partner_name"] = df["partner_code"].map(country_name_map)

    # 3. 提取月份
    df["month"] = df["period"].astype(str).str[4:6]

    # 4. 转换为宽格式（CIF进口/FOB出口分列）
    df_pivot = df.pivot_table(
        index=["year", "month", "period", "reporter_code", "reporter_name", 
               "partner_code", "partner_name", "cmd_code", "cmd_name"],
        columns="flow_code",
        values="trade_value_usd",
        aggfunc="first"
    ).reset_index()

    # 5. 重命名贸易流向列
    df_pivot = df_pivot.rename(columns={
        1: "import_cif_usd",
        2: "export_fob_usd"
    })

    # 6. 计算总贸易额（按用户要求fillna(0)后相加）
    df_pivot["total_trade_usd"] = (
        df_pivot["import_cif_usd"].fillna(0) + 
        df_pivot["export_fob_usd"].fillna(0)
    )

    # 7. 缺失值处理（保留NA）
    for col in ["import_cif_usd", "export_fob_usd"]:
        df_pivot[col] = df_pivot[col].astype(pd.Float64Dtype())

    # 8. 最终列顺序
    final_columns = [
        "year", "month", "period", "reporter_code", "reporter_name",
        "partner_code", "partner_name", "cmd_code", "cmd_name",
        "import_cif_usd", "export_fob_usd", "total_trade_usd"
    ]

    return df_pivot[final_columns].sort_values(["year", "month", "partner_code"])


def main():
    logger = setup_logging()
    logger.info("="*50)
    logger.info("UN Comtrade数据下载任务启动")
    logger.info(f"时间范围: {START_YEAR}-01 至 {END_YEAR}-12")
    logger.info(f"目标国家数: {len(COUNTRY_LIST)}")
    logger.info("="*50)

    # 初始化
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    country_name_map = {code: name for name, code in COUNTRY_LIST}
    monthly_periods = generate_monthly_periods()
    all_data = []

    # 主下载循环
    for country_name, country_code in COUNTRY_LIST:
        logger.info(f"\n开始处理: {country_name} (代码:{country_code})")
        
        for year_periods in monthly_periods:
            # 获取数据
            df = fetch_api_data(logger, country_code, year_periods)
            if not df.empty:
                all_data.append(df)
            
            # 请求间隔控制
            time.sleep(REQUEST_DELAY)
        
        logger.info(f"完成处理: {country_name}")

    # 数据合并与处理
    if all_data:
        logger.info("\n开始合并与处理数据...")
        raw_combined = pd.concat(all_data, ignore_index=True)
        final_df = process_data(raw_combined, country_name_map)

        # 保存结果
        csv_path = os.path.join(OUTPUT_DIR, CSV_FILENAME)
        final_df.to_csv(csv_path, index=False, encoding="utf-8-sig")
        
        logger.info(f"\n任务完成！")
        logger.info(f"最终数据行数: {len(final_df)}")
        logger.info(f"CSV文件已保存至: {csv_path}")
        logger.info(f"日志文件已保存至: {os.path.join(LOG_DIR, LOG_FILENAME)}")
    else:
        logger.error("\n未获取到任何数据，请检查API密钥和网络连接")

if __name__ == "__main__":
    main()
