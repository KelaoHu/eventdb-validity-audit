# -*- coding: utf-8 -*-
# 提取最终核查报告中需要人工重点复核的 104 条事件，并与 CSV 匹配。

import csv
import json
import re
from datetime import datetime
import os

REPORT_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events\事件核查报告_在线核查_20260617_170528_最终版.txt"
CSV_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events\all_events_in_plots.csv"
OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events"


def extract_focus_events_from_report(path):
    """从报告第三部分提取重点关注事件"""
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # 定位第三部分
    pattern = r"三、需关注事件汇总.*?-{40,}\n(.*?)\n\n四、逐国详细核查结果"
    match = re.search(pattern, text, re.DOTALL)
    if not match:
        raise ValueError("未在报告中找到‘三、需关注事件汇总’")

    section = match.group(1)
    events = []
    # 匹配条目，例如：
    # [Australia] FTA Talks Begin | 原月份 2005-08 | 结论 Major Issue | 建议月份 2005-05
    item_re = re.compile(
        r"\[([^\]]+)\]\s+(.+?)\s+\|\s+原月份\s+(\d{4}-\d{2})\s+\|\s+结论\s+([^|]+?)\s+\|\s+建议月份\s+(\d{4}-\d{2})"
    )
    for m in item_re.finditer(section):
        country_en = m.group(1).strip()
        event_name = m.group(2).strip()
        original_month = m.group(3).strip()
        verdict = m.group(4).strip()
        suggested_month = m.group(5).strip()
        events.append({
            "country_en": country_en,
            "event_name": event_name,
            "original_month": original_month,
            "report_verdict": verdict,
            "suggested_month": suggested_month,
        })
    return events


def load_csv_events(path):
    events = []
    with open(path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            events.append(row)
    return events


def match_focus_to_csv(focus_events, csv_events):
    """按 country_en + yearmonth + event_name 匹配"""
    csv_lookup = {}
    for row in csv_events:
        key = (
            row.get("country_en", "").strip(),
            row.get("yearmonth", "").strip(),
            row.get("event_name", "").strip(),
        )
        csv_lookup[key] = row

    matched = []
    unmatched = []
    for fe in focus_events:
        key = (fe["country_en"], fe["original_month"], fe["event_name"])
        row = csv_lookup.get(key)
        if row:
            matched.append({**fe, "csv_row": row})
        else:
            # 尝试仅按 country + month + event_name 模糊匹配
            candidates = [
                r for r in csv_events
                if r.get("country_en", "").strip() == fe["country_en"]
                and r.get("yearmonth", "").strip() == fe["original_month"]
                and fe["event_name"] in r.get("event_name", "")
            ]
            if len(candidates) == 1:
                matched.append({**fe, "csv_row": candidates[0]})
            else:
                unmatched.append(fe)
    return matched, unmatched


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    focus_events = extract_focus_events_from_report(REPORT_PATH)
    print(f"从报告提取到 {len(focus_events)} 条重点关注事件")

    csv_events = load_csv_events(CSV_PATH)
    print(f"CSV 共有 {len(csv_events)} 条事件")

    matched, unmatched = match_focus_to_csv(focus_events, csv_events)
    print(f"成功匹配 {len(matched)} 条，未匹配 {len(unmatched)} 条")

    if unmatched:
        print("未匹配事件：")
        for u in unmatched:
            print(f"  - {u}")

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = os.path.join(OUTPUT_DIR, f"focus_events_{timestamp}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({
            "count": len(matched),
            "unmatched_count": len(unmatched),
            "matched": matched,
            "unmatched": unmatched,
        }, f, ensure_ascii=False, indent=2)
    print(f"已保存：{out_path}")


if __name__ == "__main__":
    main()
