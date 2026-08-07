import os
import sys
import json
import logging
import time
import re
from datetime import datetime
from typing import List, Dict, Optional, Set

import requests

try:
    from pyDataverse.api import NativeApi
except ImportError:
    print("请先安装: pip install pyDataverse")
    sys.exit(1)


# ==================== 配置 ====================
class Config:
    API_KEY = "4ab0719b-5d23-4c58-9524-8bb70553bcd6"
    BASE_URL = "https://dataverse.harvard.edu"

    DATASET_DOI = "doi:10.7910/DVN/28075"

    OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\ICEWS"
    DOWNLOAD_DIR = os.path.join(OUTPUT_DIR, "raw_zip")
    PROGRESS_FILE = os.path.join(OUTPUT_DIR, "download_progress.json")

    START_DATE = datetime(2000, 1, 1)
    END_DATE = datetime(2023, 4, 11)

    MAX_RETRIES = 5
    TIMEOUT = 120


# ==================== 日志 ====================
def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s"
    )
    return logging.getLogger(__name__)


# ==================== 工具函数 ====================
def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def safe_filename(name):
    return re.sub(r'[\\/:*?"<>|]+', "_", name)


def extract_date(filename: str) -> Optional[datetime]:
    """
    从 ICEWS 文件名中提取“数据时间”（关键修复点）

    支持：
    events.2018.20150313082510.tab.zip → 2018
    ICEWS_2015.zip → 2015
    2012_events.zip → 2012

    注意：优先识别“数据年份”，忽略版本时间戳
    """
    # 优先匹配 events.YYYY.
    m = re.search(r"events\.(\d{4})\.", filename)
    if m:
        return datetime(int(m.group(1)), 1, 1)

    # 其次匹配独立年份
    m = re.search(r"(19|20)\d{2}", filename)
    if m:
        return datetime(int(m.group()), 1, 1)

    return None


def is_valid_file(path):
    return os.path.exists(path) and os.path.getsize(path) > 0


# ==================== 下载器 ====================
class ICEWSDownloader:

    def __init__(self, config: Config, logger):
        self.config = config
        self.logger = logger

        ensure_dir(config.DOWNLOAD_DIR)

        self.api = NativeApi(config.BASE_URL, config.API_KEY)

        self.session = requests.Session()
        self.session.headers.update({
            "X-Dataverse-key": config.API_KEY
        })

        self.processed = self.load_progress()

    # ---------------- 断点续传 ----------------
    def load_progress(self) -> Set[int]:
        if os.path.exists(self.config.PROGRESS_FILE):
            with open(self.config.PROGRESS_FILE, "r") as f:
                return set(json.load(f))
        return set()

    def save_progress(self):
        with open(self.config.PROGRESS_FILE, "w") as f:
            json.dump(list(self.processed), f)

    # ---------------- 获取文件 ----------------
    def get_files(self) -> List[Dict]:
        self.logger.info("获取 ICEWS 文件列表...")

        dataset = self.api.get_dataset(self.config.DATASET_DOI)
        data = dataset.json()

        files = data["data"]["latestVersion"]["files"]
        self.logger.info(f"共 {len(files)} 个文件")

        return files

    # ---------------- 过滤逻辑（核心） ----------------
    def filter_files(self, files: List[Dict]) -> List[Dict]:

        selected = []
        skipped_no_date = 0

        for f in files:
            data = f.get("dataFile", {})
            file_id = data.get("id")
            name = data.get("filename", "")

            if not name.lower().endswith(".zip"):
                continue

            dt = extract_date(name)
            if dt is None:
                skipped_no_date += 1
                continue

            if self.config.START_DATE <= dt <= self.config.END_DATE:
                selected.append({
                    "id": file_id,
                    "name": name,
                    "date": dt
                })

        selected.sort(key=lambda x: x["date"])

        self.logger.info(f"筛选结果：{len(selected)} 个文件")
        self.logger.info(f"无法识别日期跳过：{skipped_no_date} 个")

        return selected

    # ---------------- 下载 ----------------
    def download_file(self, file_id, filename):

        url = f"{self.config.BASE_URL}/api/access/datafile/{file_id}"
        local_path = os.path.join(
            self.config.DOWNLOAD_DIR,
            f"{file_id}_{safe_filename(filename)}"
        )

        if file_id in self.processed and is_valid_file(local_path):
            self.logger.info(f"已完成（断点续传）: {filename}")
            return True

        for attempt in range(self.config.MAX_RETRIES):
            try:
                self.logger.info(f"下载: {filename}")

                with self.session.get(url, stream=True, timeout=self.config.TIMEOUT) as r:
                    r.raise_for_status()

                    with open(local_path, "wb") as f:
                        for chunk in r.iter_content(1024 * 1024):
                            if chunk:
                                f.write(chunk)

                self.processed.add(file_id)
                self.save_progress()

                return True

            except Exception as e:
                self.logger.warning(f"失败({attempt+1}): {e}")
                time.sleep(2 ** attempt)

        self.logger.error(f"下载失败: {filename}")
        return False

    # ---------------- 主流程 ----------------
    def run(self):

        files = self.get_files()
        files = self.filter_files(files)

        success = 0
        fail = 0

        for i, f in enumerate(files, 1):
            self.logger.info(f"进度 {i}/{len(files)}")

            ok = self.download_file(f["id"], f["name"])
            if ok:
                success += 1
            else:
                fail += 1

        self.logger.info("=" * 50)
        self.logger.info(f"完成: 成功 {success} | 失败 {fail}")
        self.logger.info("=" * 50)


# ==================== 主函数 ====================
def main():
    config = Config()
    logger = setup_logging()

    downloader = ICEWSDownloader(config, logger)
    downloader.run()


if __name__ == "__main__":
    main()
