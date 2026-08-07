# -*- coding: utf-8 -*-
# 从已保存的 raw JSON 完成 CSV 更新和报告生成，避免重新调用 API。

import json
import os
from datetime import datetime
from verify_focus_events_api import (
    CSV_PATH, OUTPUT_DIR, load_csv, update_csv, generate_txt_report
)

RAW_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events\verification_focus_raw_20260617_201151.json"


def main():
    with open(RAW_PATH, "r", encoding="utf-8") as f:
        all_results = json.load(f)

    print(f"已加载 raw 结果，共 {len(all_results)} 个国家", flush=True)

    verification_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    csv_rows, fieldnames = load_csv(CSV_PATH)
    new_fieldnames = update_csv(csv_rows, fieldnames, all_results, verification_time)

    report_path = os.path.join(OUTPUT_DIR, f"事件核查人工复核_{timestamp}.txt")
    generate_txt_report(all_results, report_path, verification_time)

    print("\n全部完成。", flush=True)
    print(f"复核报告：{report_path}", flush=True)
    print(f"更新后 CSV：{CSV_PATH}", flush=True)


if __name__ == "__main__":
    main()
