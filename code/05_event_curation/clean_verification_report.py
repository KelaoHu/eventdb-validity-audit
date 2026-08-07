# -*- coding: utf-8 -*-
# Post-process verification raw JSON to produce a cleaned report.

import json
import os
from datetime import datetime

OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events"

# Find latest raw file by mtime
raw_files = [f for f in os.listdir(OUTPUT_DIR) if f.startswith("verification_raw_") and f.endswith(".json") and not f.endswith("_v2.json")]
if not raw_files:
    raise FileNotFoundError("No verification_raw_*.json found")
raw_files.sort(key=lambda f: os.path.getmtime(os.path.join(OUTPUT_DIR, f)), reverse=True)
raw_path = os.path.join(OUTPUT_DIR, raw_files[0])
print(f"Using {raw_path}")

with open(raw_path, "r", encoding="utf-8") as f:
    raw_data = json.load(f)


def get_field(d, key, default=""):
    if not isinstance(d, dict):
        return default
    val = d.get(key)
    return str(val).strip() if val is not None else default


def is_search_failure(notes):
    if not notes:
        return True
    notes_l = notes.lower()
    return any(k in notes_l for k in ["search error", "no snippets", "no web search", "search query failed", "no source retrieved", "unable to verify", "cannot confirm from provided snippets"])


# Each country may appear multiple times in raw_data as progress was appended.
# Keep the latest pass1 and pass2 batches per country.
country_pass1 = {}
country_pass2 = {}
for country_entry in raw_data:
    country = country_entry.get("country")
    if not country:
        continue
    if "pass1" in country_entry:
        country_pass1[country] = country_entry["pass1"]
    if "pass2" in country_entry:
        country_pass2[country] = country_entry["pass2"]

records = []
for country in sorted(country_pass1.keys()):
    pass1_batches = country_pass1.get(country, [])
    pass2_batches = country_pass2.get(country, [])

    # Build first pass verdicts by event key
    first = {}
    for batch in pass1_batches:
        events = batch.get("events", [])
        verdicts = batch.get("verdicts", []) if isinstance(batch.get("verdicts"), list) else []
        for ev, v in zip(events, verdicts):
            key = f"{ev['country_en']}::{ev['event_name']}::{ev['yearmonth']}"
            first[key] = (ev, v)

    # Build second pass verdicts by event key
    second = {}
    for batch in pass2_batches:
        events = batch.get("events", [])
        verdicts = batch.get("verdicts", []) if isinstance(batch.get("verdicts"), list) else []
        for ev, v in zip(events, verdicts):
            key = f"{ev['country_en']}::{ev['event_name']}::{ev['yearmonth']}"
            second[key] = (ev, v)

    for key, (ev, v1) in first.items():
        ev2, v2 = second.get(key, (None, None))
        if ev2 is not None:
            ev = ev2
        orig_month = ev.get("yearmonth", "") if ev else ""
        verdict1 = get_field(v1, "verdict", "Error") or "Error"
        cm1 = get_field(v1, "corrected_month", orig_month) or orig_month
        notes1 = get_field(v1, "notes")

        if v2 is None:
            final = {
                "country_en": ev.get("country_en", ""),
                "country_cn": ev.get("country_cn", ""),
                "event_name": ev.get("event_name", ""),
                "original_month": orig_month,
                "pass1_verdict": verdict1,
                "pass1_corrected_month": cm1,
                "pass1_notes": notes1,
                "pass2_verdict": "",
                "pass2_corrected_month": "",
                "pass2_notes": "",
                "final_verdict": verdict1,
                "final_corrected_month": cm1,
                "final_corrected_details": get_field(v1, "corrected_details"),
                "notes": notes1,
                "discrepancy": False,
            }
        else:
            verdict2 = get_field(v2, "verdict", "Error") or "Error"
            cm2 = get_field(v2, "corrected_month", orig_month) or orig_month
            notes2 = get_field(v2, "notes")

            # If second pass only failed due to search errors, keep first pass
            if verdict2 == "Unverifiable" and is_search_failure(notes2) and verdict1 not in ("Error", ""):
                final_verdict = verdict1
                final_cm = cm1
                final_details = get_field(v1, "corrected_details")
                notes = f"[Pass1 {verdict1}] {notes1} | [Pass2 search failed] kept Pass1."
                discrepancy = False
            else:
                final_verdict = verdict2
                final_cm = cm2
                final_details = get_field(v2, "corrected_details")
                notes = f"[Pass1 {verdict1}] {notes1} | [Pass2 {verdict2}] {notes2}"
                discrepancy = (verdict1 != verdict2) or (cm1 != cm2)
                if discrepancy:
                    final_verdict = "Needs Review"
                    if cm1 != cm2:
                        notes += f" | Month discrepancy: pass1={cm1}, pass2={cm2}."

            final = {
                "country_en": ev.get("country_en", ""),
                "country_cn": ev.get("country_cn", ""),
                "event_name": ev.get("event_name", ""),
                "original_month": orig_month,
                "pass1_verdict": verdict1,
                "pass1_corrected_month": cm1,
                "pass1_notes": notes1,
                "pass2_verdict": verdict2,
                "pass2_corrected_month": cm2,
                "pass2_notes": notes2,
                "final_verdict": final_verdict,
                "final_corrected_month": final_cm,
                "final_corrected_details": final_details,
                "notes": notes,
                "discrepancy": discrepancy,
            }
        records.append(final)

# Sort like CSV: by country, yearmonth
records.sort(key=lambda r: (r["country_en"], r["original_month"], r["event_name"]))


def generate_report(path, records):
    counts = {"Verified": 0, "Minor Issue": 0, "Major Issue": 0, "Unverifiable": 0, "False": 0, "Needs Review": 0, "Error": 0}
    for r in records:
        v = r.get("final_verdict", "Error")
        counts[v] = counts.get(v, 0) + 1

    lines = []
    lines.append("=" * 80)
    lines.append("中国与主要贸易伙伴双边关键事件核查报告（清洗版）")
    lines.append("核查方式：在线核查接口 + DuckDuckGo 联网搜索")
    lines.append(f"生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"原始数据：{raw_path}")
    lines.append(f"事件总数：{len(records)}")
    lines.append("=" * 80)
    lines.append("")
    lines.append("一、核查原则")
    lines.append("1. 仅采信权威机构来源：各国政府/外交部官网、官方新闻稿、主流通讯社")
    lines.append("   （新华社、路透社、美联社、法新社、共同社、塔斯社、SBS、ABC、BBC 等）。")
    lines.append("2. 严禁引用或采信个人社交媒体、论坛、博客、自媒体等缺乏机构背书的信息。")
    lines.append("3. 核查精度为年月级别；对持续过程类事件，以最具标志性的月份为准。")
    lines.append("4. 第一轮核查覆盖全部事件；仅对未通过或存疑事件执行第二轮复核。")
    lines.append("5. 若第二轮因网络搜索失败而未能复核，保留第一轮结论，避免误判。")
    lines.append("")
    lines.append("二、总体统计")
    for v, c in counts.items():
        pct = c / len(records) * 100 if records else 0
        lines.append(f"  {v}: {c} ({pct:.1f}%)")
    lines.append("")

    issue_records = [r for r in records if r.get("final_verdict") != "Verified"]
    lines.append(f"三、需关注事件汇总（共 {len(issue_records)} 条）")
    lines.append("-" * 80)
    for r in issue_records:
        lines.append(
            f"[{r['country_en']}] {r['event_name']} | 原月份 {r['original_month']} | "
            f"结论 {r['final_verdict']} | 建议月份 {r.get('final_corrected_month','-')}"
        )
        lines.append(f"    说明：{r.get('notes','')}")
        if r.get("final_corrected_details"):
            lines.append(f"    修正详情：{r['final_corrected_details']}")
        if r.get("discrepancy"):
            lines.append("    ⚠ 两轮结论存在分歧，请人工复核。")
        lines.append("")
    lines.append("")

    lines.append("四、逐国详细核查结果")
    lines.append("=" * 80)
    countries = sorted(set(r["country_en"] for r in records))
    for country in countries:
        country_records = [r for r in records if r["country_en"] == country]
        lines.append("")
        lines.append(f"【{country}】（{len(country_records)} 条）")
        lines.append("-" * 80)
        for r in country_records:
            lines.append(f"事件：{r['event_name']}")
            lines.append(f"  原月份：{r['original_month']}")
            if r.get("pass1_verdict"):
                lines.append(f"  第一轮：{r['pass1_verdict']} -> 建议月份 {r.get('pass1_corrected_month','-')}")
            if r.get("pass2_verdict"):
                lines.append(f"  第二轮：{r['pass2_verdict']} -> 建议月份 {r.get('pass2_corrected_month','-')}")
            lines.append(f"  最终结论：{r['final_verdict']} | 最终建议月份：{r.get('final_corrected_month','-')}")
            lines.append(f"  说明：{r.get('notes','')}")
            if r.get("final_corrected_details"):
                lines.append(f"  修正详情：{r['final_corrected_details']}")
            if r.get("discrepancy"):
                lines.append("  ⚠ 两轮结论存在分歧，请人工复核。")
            lines.append("")

    lines.append("=" * 80)
    lines.append("五、建议人工重点复核清单")
    lines.append("-" * 80)
    review = [r for r in records if r.get("final_verdict") in ("Major Issue", "False", "Unverifiable", "Needs Review", "Error")]
    if not review:
        lines.append("无。")
    for r in review:
        lines.append(
            f"- [{r['country_en']}] {r['event_name']} ({r['original_month']}) -> {r['final_verdict']}"
        )
    lines.append("")
    lines.append("=" * 80)
    lines.append("报告结束")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
report_path = os.path.join(OUTPUT_DIR, f"事件核查报告_在线核查_{timestamp}_清洗版.txt")
generate_report(report_path, records)
print(f"Cleaned report saved: {report_path}")
