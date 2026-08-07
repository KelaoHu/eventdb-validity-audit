import os
import sys
import time
import zipfile
from datetime import datetime, timedelta

import requests
import keyboard

# -------------------------- 配置区域 --------------------------
# 时间范围：2000年1月1日 至 2025年12月31日
START_DATE = datetime(2000, 1, 1)
END_DATE = datetime(2025, 12, 31)

# 保存路径（保持不变）
SAVE_DIR1 = r'C:\Users\胡克劳\Desktop\GDELT'
SAVE_DIR2 = r'C:\Users\胡克劳\Desktop\GDELT\终端文字记录'
SAVE_DIR_ZIP = r'C:\Users\胡克劳\Desktop\GDELT\ZIP'

# 断点续跑：进度记录文件（改成新名字）
PROGRESS_FILE = os.path.join(SAVE_DIR2, 'zip_download_checkpoint.txt')

# 生成时间戳，用于终端日志命名
RUN_TIME = datetime.now().strftime('%Y%m%d_%H%M%S')

# 终端日志保存路径（文件名加入生成时间）
LOG_FILE = os.path.join(SAVE_DIR2, f'终端文字记录_{RUN_TIME}.txt')

# GDELT数据下载基础路径
BASE_URL = 'http://data.gdeltproject.org/events/'

# 最大重试次数（仅针对5xx服务器错误/网络异常，404直接跳过）
MAX_RETRIES = 15
# ----------------------------------------------------------------


# ==================== 双重输出日志类 ====================
class DualLogger:
    """
    同时将 print 内容输出到终端和文件
    """
    def __init__(self, log_file_path):
        self.terminal = sys.stdout
        os.makedirs(os.path.dirname(log_file_path), exist_ok=True)
        self.log = open(log_file_path, "a", encoding="utf-8")

    def write(self, message):
        self.terminal.write(message)
        self.log.write(message)
        self.flush()

    def flush(self):
        self.terminal.flush()
        self.log.flush()


print(">>> 正在启动终端记录功能...")
sys.stdout = DualLogger(LOG_FILE)
print(f">>> 终端日志将同步保存至: {LOG_FILE}")

# ==================== 高速连接池 ====================
print(">>> 初始化高速连接池...")
session = requests.Session()
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept-Encoding': 'gzip, deflate',
    'Connection': 'keep-alive'
})

# ==================== 暂停/继续逻辑 ====================
is_paused = False
pause_hotkey = 'space'

def toggle_pause():
    global is_paused
    is_paused = not is_paused
    if is_paused:
        print("\n\n[暂停] 已按空格键暂停，再次按空格键继续...\n")
    else:
        print("\n[继续] 已按空格键，继续下载...\n")

keyboard.add_hotkey(pause_hotkey, toggle_pause)
print(f">>> 提示：按 空格键 可随时暂停/继续下载\n")

# ==================== 创建目录 ====================
os.makedirs(SAVE_DIR1, exist_ok=True)
os.makedirs(SAVE_DIR2, exist_ok=True)
os.makedirs(SAVE_DIR_ZIP, exist_ok=True)


# ==================== 工具函数 ====================
def is_valid_zip(zip_path: str) -> bool:
    """
    检查本地 ZIP 是否完整可读
    """
    if not os.path.exists(zip_path):
        return False
    if os.path.getsize(zip_path) == 0:
        return False
    try:
        if not zipfile.is_zipfile(zip_path):
            return False
        with zipfile.ZipFile(zip_path, 'r') as zf:
            bad_file = zf.testzip()
            return bad_file is None
    except Exception:
        return False


def download_file(url: str, local_path: str) -> bool:
    """
    下载单个文件，带重试；返回是否成功
    """
    tmp_path = local_path + ".part"

    # 如果临时文件残留，先删掉
    if os.path.exists(tmp_path):
        try:
            os.remove(tmp_path)
        except Exception:
            pass

    retry_count = 0
    while retry_count < MAX_RETRIES:
        try:
            response = session.get(url, timeout=(10, 300), stream=True)

            if response.status_code == 404:
                print(f'  [跳过] 文件不存在（404）：{os.path.basename(local_path)}')
                return False

            if 500 <= response.status_code < 600:
                retry_count += 1
                print(f'  [警告] 服务器返回 {response.status_code}，第 {retry_count} 次重试，等待 5 秒...')
                time.sleep(5)
                continue

            response.raise_for_status()

            total = 0
            with open(tmp_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if chunk:
                        f.write(chunk)
                        total += len(chunk)

            if total == 0:
                retry_count += 1
                print(f'  [警告] 下载内容为空，第 {retry_count} 次重试，等待 5 秒...')
                time.sleep(5)
                continue

            os.replace(tmp_path, local_path)

            if is_valid_zip(local_path):
                return True
            else:
                print('  [警告] 下载后 ZIP 校验失败，准备重下...')
                try:
                    os.remove(local_path)
                except Exception:
                    pass
                retry_count += 1
                time.sleep(3)

        except requests.exceptions.RequestException as e:
            retry_count += 1
            print(f'  [错误] 网络异常: {str(e)}，第 {retry_count} 次重试，等待 5 秒...')
            time.sleep(5)
        except Exception as e:
            retry_count += 1
            print(f'  [错误] 处理下载时出错: {str(e)}，第 {retry_count} 次重试，等待 5 秒...')
            time.sleep(5)

    if os.path.exists(tmp_path):
        try:
            os.remove(tmp_path)
        except Exception:
            pass
    return False


def iter_year_files(start_year: int, end_year: int):
    for year in range(start_year, end_year + 1):
        filename = f"{year}.zip"
        yield filename, f"{BASE_URL}{filename}"


def iter_month_files(start_date: datetime, end_date: datetime):
    current = datetime(start_date.year, start_date.month, 1)
    while current <= end_date:
        filename = f"{current.year}{current.month:02d}.zip"
        yield filename, f"{BASE_URL}{filename}"

        if current.month == 12:
            current = datetime(current.year + 1, 1, 1)
        else:
            current = datetime(current.year, current.month + 1, 1)


def iter_daily_files(start_date: datetime, end_date: datetime):
    current = start_date
    while current <= end_date:
        filename = f"{current.strftime('%Y%m%d')}.export.CSV.zip"
        yield filename, f"{BASE_URL}{filename}"
        current += timedelta(days=1)


def build_archive_plan(start_date: datetime, end_date: datetime):
    """
    2000-2005：年包
    2006-01 到 2013-03：月包
    2013-04-01 到 2025-12-31：日包
    """
    plan = []

    # 年包：2000-2005
    year_start = max(start_date.year, 2000)
    year_end = min(end_date.year, 2005)
    if year_start <= year_end:
        for filename, url in iter_year_files(year_start, year_end):
            plan.append((filename, url))

    # 月包：2006-01 到 2013-03
    month_start = datetime(2006, 1, 1)
    month_end = datetime(2013, 3, 1)
    if end_date >= month_start:
        actual_month_start = max(start_date, month_start)
        actual_month_end = min(end_date, month_end)
        if actual_month_start <= actual_month_end:
            for filename, url in iter_month_files(actual_month_start, actual_month_end):
                plan.append((filename, url))

    # 日包：2013-04-01 到 2025-12-31
    daily_start = datetime(2013, 4, 1)
    if end_date >= daily_start:
        actual_daily_start = max(start_date, daily_start)
        actual_daily_end = min(end_date, end_date)
        if actual_daily_start <= actual_daily_end:
            for filename, url in iter_daily_files(actual_daily_start, actual_daily_end):
                plan.append((filename, url))

    return plan


def load_checkpoint():
    """
    读取断点：返回“下一个要处理的文件名”
    """
    if not os.path.exists(PROGRESS_FILE):
        return None
    try:
        with open(PROGRESS_FILE, 'r', encoding='utf-8') as f:
            value = f.read().strip()
            return value if value else None
    except Exception as e:
        print(f">>> [警告] 读取进度文件失败，将从头开始: {e}")
        return None


def save_checkpoint(next_filename: str):
    try:
        with open(PROGRESS_FILE, 'w', encoding='utf-8') as f:
            f.write(next_filename)
    except Exception as e:
        print(f'  [警告] 保存进度文件失败: {e}')


# ==================== 主流程：仅下载 ZIP ====================
print("\n--- 开始下载 GDELT ZIP 归档文件 ---")

archive_plan = build_archive_plan(START_DATE, END_DATE)
print(f">>> 共生成待处理文件数：{len(archive_plan)}")

checkpoint = load_checkpoint()
start_index = 0

if checkpoint:
    for i, (filename, _) in enumerate(archive_plan):
        if filename == checkpoint:
            start_index = i
            print(f">>> [断点续跑] 发现进度文件，将从 {filename} 继续处理...")
            break
    else:
        print(">>> [断点续跑] 进度文件未匹配到计划列表，将从头开始...")

for idx in range(start_index, len(archive_plan)):
    while is_paused:
        time.sleep(0.1)

    filename, file_url = archive_plan[idx]
    local_zip_path = os.path.join(SAVE_DIR_ZIP, filename)

    print(f'正在检索: {filename}')

    # 1) 先检查本地是否已有且完整
    if is_valid_zip(local_zip_path):
        print(f'  [本地] 已存在且完整，跳过: {local_zip_path}')
    else:
        # 2) 已存在但损坏，先删除再下载
        if os.path.exists(local_zip_path):
            print(f'  [本地] 文件存在但校验失败，准备重新下载: {local_zip_path}')
            try:
                os.remove(local_zip_path)
            except Exception as e:
                print(f'  [警告] 删除损坏文件失败: {e}')

        print(f'  [下载] 开始下载: {file_url}')
        ok = download_file(file_url, local_zip_path)

        if ok:
            print(f'  [保存] ZIP 已保存并校验通过: {local_zip_path}')
        else:
            print(f'  [跳过] {filename} 下载失败，继续下一个文件')

    # 3) 保存断点：下一个文件名
    next_filename = archive_plan[idx + 1][0] if idx + 1 < len(archive_plan) else ""
    if next_filename:
        save_checkpoint(next_filename)
    else:
        save_checkpoint("")

# ==================== 清理与结束 ====================
if os.path.exists(PROGRESS_FILE):
    try:
        os.remove(PROGRESS_FILE)
        print("\n>>> 任务全部完成，进度文件已清除。")
    except Exception as e:
        print(f"\n>>> 任务完成，但清除进度文件失败：{e}")
else:
    print("\n>>> 任务全部完成。")

print(f">>> 所有 ZIP 文件已处理完毕，保存目录：{SAVE_DIR_ZIP}")
