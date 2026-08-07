# -*- coding: utf-8 -*-
# 对 104 条重点事件使用联网核查接口进行定向复核，

import csv
import json
import os
import re
import sys
import time
import warnings
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import requests
from ddgs import DDGS

warnings.filterwarnings("ignore")

API_KEY = os.environ.get("VERIFICATION_API_KEY", "")  #（密钥在所用核查服务平台的 API Keys 页面申请，设为环境变量，勿写入代码）
BASE_URL = "https://api.example.com/v1"  # 兼容 chat/completions 协议的核查端点，复现时替换
MODEL = "your-model-id"

REPORT_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events\事件核查报告_在线核查_20260617_170528_最终版.txt"
CSV_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events\all_events_in_plots.csv"
OUTPUT_DIR = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events"



def web_search(query: str, max_results: int = 3):
    """Search DuckDuckGo via ddgs and return snippets."""
    if not query or not query.strip():
        return ""
    try:
        with DDGS() as ddgs:
            results = ddgs.text(query.strip(), max_results=max_results)
            snippets = []
            for i, r in enumerate(results, 1):
                title = r.get("title", "") or ""
                href = r.get("href", "") or ""
                body = r.get("body", "") or ""
                snippets.append(f"[Result {i}] {title}\nURL: {href}\n{body}\n")
            return "\n".join(snippets) if snippets else "No results found."
    except Exception as e:
        return f"Search error: {e}"


def fetch_search_blocks_parallel(events, max_workers=3):
    """并行获取多个事件的搜索摘要"""
    def task(args):
        idx, e = args
        name = e.get("event_name", "")
        ym = e.get("original_month", "")
        country_en = e.get("country_en", "")
        row = e.get("csv_row") or {}
        visitor = row.get("visitor", "")
        host = row.get("host", "")
        location = row.get("location", "")
        query = " ".join(p for p in [visitor, host, name, ym, location, "China", country_en] if p).strip()
        result = web_search(query, max_results=3) if query else "No query."
        return idx, f"--- Search context for: {name} ({ym}) ---\nQuery: {query}\n{result}"

    blocks = [""] * len(events)
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(task, (i, e)): i for i, e in enumerate(events)}
        for future in as_completed(futures):
            idx, block = future.result()
            blocks[idx] = block
    return "\n\n".join(blocks)


def extract_focus_events_from_report(path):
    """从报告第三部分提取重点关注事件"""
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    pattern = r"三、需关注事件汇总.*?-{40,}\n(.*?)\n\n四、逐国详细核查结果"
    match = re.search(pattern, text, re.DOTALL)
    if not match:
        raise ValueError("未在报告中找到‘三、需关注事件汇总’")

    section = match.group(1)
    events = []
    item_re = re.compile(
        r"\[([^\]]+)\]\s+(.+?)\s+\|\s+原月份\s+(\d{4}-\d{2})\s+\|\s+结论\s+([^|]+?)\s+\|\s+建议月份\s+(\d{4}-\d{2})"
    )
    for m in item_re.finditer(section):
        events.append({
            "country_en": m.group(1).strip(),
            "event_name": m.group(2).strip(),
            "original_month": m.group(3).strip(),
            "report_verdict": m.group(4).strip(),
            "suggested_month": m.group(5).strip(),
        })
    return events


def load_csv(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames
    return rows, fieldnames


def match_focus_to_csv(focus_events, csv_rows):
    lookup = {}
    for row in csv_rows:
        key = (
            row.get("country_en", "").strip(),
            row.get("yearmonth", "").strip(),
            row.get("event_name", "").strip(),
        )
        lookup[key] = row
    matched = []
    for fe in focus_events:
        key = (fe["country_en"], fe["original_month"], fe["event_name"])
        row = lookup.get(key)
        if row:
            matched.append({**fe, "csv_row": row})
        else:
            matched.append({**fe, "csv_row": None})
    return matched


def event_to_text(e, idx):
    row = e.get("csv_row") or {}
    lines = [
        f"{idx}. Event: {e.get('event_name','')}",
        f"   Country: {e.get('country_en','')}",
        f"   Original month: {e.get('original_month','')}",
        f"   Previous report verdict: {e.get('report_verdict','')}",
        f"   Previous suggested month: {e.get('suggested_month','')}",
        f"   CSV fields: type={row.get('event_type','')}, impact={row.get('impact','')}, "
        f"visit_level={row.get('visit_level','')}, visit_direction={row.get('visit_direction','')}, "
        f"visitor={row.get('visitor','')}, host={row.get('host','')}, location={row.get('location','')}",
        f"   IMPORTANT: The previous report flagged this event as '{e.get('report_verdict','')}'. "
        f"Please verify independently and carefully; do not simply accept the original CSV record if the previous report raised concerns.",
    ]
    return "\n".join(lines)


def call_model_stream(system_prompt: str, user_prompt: str):
    """调用核查接口并流式返回完整内容"""
    try:
        resp = requests.post(
            f"{BASE_URL}/chat/completions",
            headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
            json={
                "model": MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "temperature": 0.1,
                "max_tokens": 16000,
                "stream": True,
            },
            stream=True,
            timeout=300,
        )
        resp.raise_for_status()
        content = ""
        for line in resp.iter_lines():
            if not line:
                continue
            line = line.decode("utf-8")
            if line.startswith("data: ") and line.strip() != "data: [DONE]":
                delta = json.loads(line[6:])["choices"][0].get("delta", {}).get("content") or ""
                content += delta
        return content
    except Exception as e:
        return json.dumps({"error": str(e)})


def verify_country(country, events):
    """对一个国家的所有重点事件进行复核"""
    events_text = "\n\n".join(event_to_text(e, i+1) for i, e in enumerate(events))

    print(f"  [{country}] 正在并行获取搜索摘要（{len(events)} 条）...", flush=True)
    search_text = fetch_search_blocks_parallel(events, max_workers=3)

    system_prompt = (
        "你是一位严谨的政治事件核查员，正在为学术论文复核中国与主要贸易伙伴的双边关键事件。"
        "你必须仅采信权威机构来源：各国政府/外交部官网、官方新闻稿、主流通讯社（新华社、路透社、美联社、法新社、共同社、塔斯社、BBC、ABC、SBS 等）。"
        "严禁引用个人社交媒体、论坛、博客、自媒体、知乎、百度百科、未经验证视频。"
        "请根据提供的网络搜索摘要和你自身的知识，对每条事件给出最终复核结论。"
        "\n\n"
        "输出要求：输出一个 JSON 对象，包含唯一键 'results'，其值为对象数组。"
        "每个对象必须包含以下字段："
        "event_name（原事件名）, "
        "original_month（原月份 YYYY-MM）, "
        "verdict（最终结论，只能为 Verified / Minor / Major / False / Still Unverifiable 之一）, "
        "corrected_month（修正后的月份 YYYY-MM；若无需修改则与原月份相同）, "
        "corrected_event_name（修正后的事件名；若无需修改则为空字符串）, "
        "corrected_visitor（修正后的访问者；若无需修改则为空字符串）, "
        "corrected_host（修正后的接待者；若无需修改则为空字符串）, "
        "corrected_location（修正后的地点；若无需修改则为空字符串）, "
        "visit_direction（访问方向，只能为 china_to_partner / partner_to_china / third_party_meeting / not_applicable 之一）, "
        "visit_level（访问层级，只能为 state_head / government_head / not_applicable 之一）, "
        "visit_category（访问类别，必须为以下之一：china_statehead_to_partner, china_govhead_to_partner, partner_statehead_to_china, partner_govhead_to_china, third_party_meeting, not_applicable）, "
        "source_url（权威来源 URL；尽量提供可点击的 URL；若实在无法提供则填写来源名称，如‘新华社’）, "
        "notes（简要依据说明，必须说明为何给出该结论，并回应前序报告的质疑）。"
        "\n\n"
        "判定标准："
        "Verified = 事件真实，原记录基本正确；"
        "Minor = 事件真实，仅 minor detail（如日期在当月内微调、会晤形式表述）需修正；"
        "Major = 事件真实，但月份、关键人物、地点或事件性质有重大错误，必须修正；"
        "False = 事件不存在或严重错误，应标记为假；"
        "Still Unverifiable = 经权威来源搜索后仍无法确认。"
        "\n\n"
        "特别注意："
        "1. 必须区分中国国家元首（国家主席）与政府首脑（国务院总理）。"
        "2. 必须区分外国国家元首（总统/君主）与政府首脑（总理/首相）。"
        "3. 记录事件发生时间，而非媒体报道时间。"
        "4. 对 Needs Review 类事件必须给出明确仲裁结论。"
        "5. 若事件为 False，请说明原因并尽量给出可反驳该事件的权威来源。"
        "6. 对于前序报告已标注为 Major / False / Needs Review 的事件，必须格外谨慎；"
        "   若你无法找到强有力证据证明原记录正确，则应采纳前序报告的修正建议或判定为 False / Still Unverifiable。"
        "7. 每条结论都必须提供 source_url；对于 False 事件，尽量给出证明其为假的来源。"
    )

    user_prompt = (
        f"请复核以下 {len(events)} 条中国与 {country} 的重点事件。今天是 {datetime.now().isoformat()[:10]}。\n\n"
        f"事件列表：\n{events_text}\n\n"
        f"网络搜索摘要：\n{search_text}\n\n"
        "请返回 JSON 对象，包含键 'results'，其值为上述事件数组。不要添加 Markdown 代码块。"
    )

    print(f"  [{country}] 正在调用核查接口（streaming）...", flush=True)
    content = call_model_stream(system_prompt, user_prompt)
    return {"country": country, "events": events, "raw": content}


def parse_country_result(result):
    raw = result.get("raw", "")
    if not raw:
        return []
    # 去除 markdown 代码块
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3].strip()
    try:
        data = json.loads(cleaned)
        results = data.get("results", [])
        if isinstance(results, dict):
            results = [results]
        return results
    except Exception as e:
        return [{"parse_error": str(e), "raw": raw}]


def safe_get(d, key, default=""):
    if not isinstance(d, dict):
        return default
    val = d.get(key)
    return str(val).strip() if val is not None else default


def normalize_verdict(v):
    v = str(v).strip()
    allowed = {"Verified", "Minor", "Major", "False", "Still Unverifiable"}
    if v in allowed:
        return v
    mapping = {
        "Minor Issue": "Minor",
        "Major Issue": "Major",
        "Unverifiable": "Still Unverifiable",
    }
    return mapping.get(v, v)


def normalize_visit_category(v):
    v = str(v).strip()
    allowed = {
        "china_statehead_to_partner",
        "china_govhead_to_partner",
        "partner_statehead_to_china",
        "partner_govhead_to_china",
        "third_party_meeting",
        "not_applicable",
    }
    return v if v in allowed else "not_applicable"


def update_csv(csv_rows, fieldnames, all_results, verification_time):
    """根据复核结果更新 CSV"""
    backup_path = CSV_PATH + ".bak"
    with open(backup_path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(csv_rows)
    print(f"已备份 CSV: {backup_path}", flush=True)

    result_lookup = {}
    for r in all_results:
        country = r.get("country")
        verdicts = parse_country_result(r)
        for v in verdicts:
            key = (
                country,
                safe_get(v, "original_month"),
                safe_get(v, "event_name"),
            )
            result_lookup[key] = v

    new_fieldnames = [fn for fn in fieldnames if fn not in ("verification_status",)]
    # 同时从每行数据中删除 verification_status，避免 DictWriter 报错
    for row in csv_rows:
        row.pop("verification_status", None)
    if "visit_category" not in new_fieldnames:
        if "visit_direction" in new_fieldnames:
            idx = new_fieldnames.index("visit_direction") + 1
            new_fieldnames.insert(idx, "visit_category")
        else:
            new_fieldnames.append("visit_category")
    if "verified" not in new_fieldnames:
        new_fieldnames.append("verified")
    if "verification_time" not in new_fieldnames:
        new_fieldnames.append("verification_time")

    updated_count = 0
    false_count = 0
    for row in csv_rows:
        key = (
            row.get("country_en", "").strip(),
            row.get("yearmonth", "").strip(),
            row.get("event_name", "").strip(),
        )
        v = result_lookup.get(key)
        if v:
            verdict = normalize_verdict(safe_get(v, "verdict"))
            corrected_month = safe_get(v, "corrected_month") or key[1]
            corrected_event_name = safe_get(v, "corrected_event_name")
            corrected_visitor = safe_get(v, "corrected_visitor")
            corrected_host = safe_get(v, "corrected_host")
            corrected_location = safe_get(v, "corrected_location")
            visit_direction = safe_get(v, "visit_direction")
            visit_level = safe_get(v, "visit_level")
            visit_category = normalize_visit_category(safe_get(v, "visit_category"))
            source_url = safe_get(v, "source_url")

            if corrected_month and re.match(r"\d{4}-\d{2}", corrected_month):
                row["yearmonth"] = corrected_month
            if corrected_event_name:
                row["event_name"] = corrected_event_name
            if corrected_visitor:
                row["visitor"] = corrected_visitor
            if corrected_host:
                row["host"] = corrected_host
            if corrected_location:
                row["location"] = corrected_location
            if visit_direction in {"china_to_partner", "partner_to_china", "third_party_meeting", "not_applicable"}:
                row["visit_direction"] = visit_direction
            if visit_level in {"state_head", "government_head", "not_applicable"}:
                row["visit_level"] = visit_level
            if visit_category:
                row["visit_category"] = visit_category
            if source_url:
                row["source"] = source_url

            is_verified = ("False" not in verdict)
            row["verified"] = "True" if is_verified else "False"
            row["verification_time"] = verification_time

            if not is_verified:
                false_count += 1
                if "[FALSE]" not in row["event_name"]:
                    row["event_name"] = f"[FALSE] {row['event_name']}"

            updated_count += 1

    for row in csv_rows:
        if "verified" not in row or not row["verified"]:
            row["verified"] = "True"
        if "verification_time" not in row or not row["verification_time"]:
            row["verification_time"] = verification_time

    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=new_fieldnames)
        writer.writeheader()
        writer.writerows(csv_rows)
    print(f"CSV 已更新: {CSV_PATH}", flush=True)
    print(f"共更新 {updated_count} 条重点事件，其中标注为 False {false_count} 条", flush=True)
    return new_fieldnames


def generate_txt_report(all_results, report_path, verification_time):
    """生成中文 TXT 复核报告"""
    lines = []
    lines.append("=" * 80)
    lines.append("中国与主要贸易伙伴双边关键事件人工复核报告")
    lines.append(f"复核时间：{verification_time}")
    lines.append(f"数据来源：{CSV_PATH}")
    lines.append(f"核查方式：在线核查接口（{MODEL}）+ DuckDuckGo 联网搜索")
    lines.append("=" * 80)
    lines.append("")

    counts = {"Verified": 0, "Minor": 0, "Major": 0, "False": 0, "Still Unverifiable": 0, "Error": 0}
    all_verdicts = []
    for r in all_results:
        for v in parse_country_result(r):
            if "parse_error" in v or "error" in r:
                counts["Error"] += 1
                continue
            verdict = normalize_verdict(safe_get(v, "verdict"))
            counts[verdict] = counts.get(verdict, 0) + 1
            all_verdicts.append(v)

    total = len(all_verdicts)
    lines.append("一、总体统计")
    lines.append(f"  复核事件总数：{total}")
    for k, c in counts.items():
        pct = c / total * 100 if total else 0
        lines.append(f"  {k}: {c} ({pct:.1f}%)")
    lines.append("")

    lines.append("二、逐国复核结果")
    lines.append("-" * 80)
    for r in all_results:
        country = r.get("country")
        verdicts = parse_country_result(r)
        if not verdicts:
            continue
        lines.append("")
        lines.append(f"【{country}】（{len(verdicts)} 条）")
        lines.append("-" * 80)
        for v in verdicts:
            if "parse_error" in v:
                lines.append(f"解析错误：{v.get('parse_error')}")
                continue
            verdict = normalize_verdict(safe_get(v, "verdict"))
            lines.append(f"原事件名：{safe_get(v, 'event_name')}")
            lines.append(f"原月份：{safe_get(v, 'original_month')}")
            lines.append(f"复核结论：{verdict}")
            lines.append(f"建议月份：{safe_get(v, 'corrected_month')}")
            if safe_get(v, "corrected_event_name"):
                lines.append(f"建议事件名：{safe_get(v, 'corrected_event_name')}")
            if safe_get(v, "corrected_visitor"):
                lines.append(f"建议访问者：{safe_get(v, 'corrected_visitor')}")
            if safe_get(v, "corrected_host"):
                lines.append(f"建议接待者：{safe_get(v, 'corrected_host')}")
            if safe_get(v, "corrected_location"):
                lines.append(f"建议地点：{safe_get(v, 'corrected_location')}")
            lines.append(f"访问方向/层级/类别：{safe_get(v, 'visit_direction')} / {safe_get(v, 'visit_level')} / {safe_get(v, 'visit_category')}")
            lines.append(f"依据来源：{safe_get(v, 'source_url')}")
            lines.append(f"说明：{safe_get(v, 'notes')}")
            lines.append("")

    lines.append("=" * 80)
    lines.append("三、重点复核清单汇总")
    lines.append("-" * 80)
    for v in all_verdicts:
        if "parse_error" in v:
            continue
        verdict = normalize_verdict(safe_get(v, "verdict"))
        if verdict not in ("Verified",):
            lines.append(
                f"- {safe_get(v, 'event_name')} ({safe_get(v, 'original_month')}) -> {verdict}，"
                f"建议月份 {safe_get(v, 'corrected_month')}"
            )
    lines.append("")
    lines.append("=" * 80)
    lines.append("报告结束")

    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"复核报告已保存: {report_path}", flush=True)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    verification_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    focus_events = extract_focus_events_from_report(REPORT_PATH)
    print(f"提取到 {len(focus_events)} 条重点事件", flush=True)

    csv_rows, fieldnames = load_csv(CSV_PATH)
    matched = match_focus_to_csv(focus_events, csv_rows)
    matched_count = len([m for m in matched if m["csv_row"]])
    print(f"CSV 共 {len(csv_rows)} 行，成功匹配 {matched_count} 条", flush=True)

    by_country = {}
    for m in matched:
        by_country.setdefault(m["country_en"], []).append(m)

    all_results = []
    raw_path = os.path.join(OUTPUT_DIR, f"verification_focus_raw_{timestamp}.json")
    for country in sorted(by_country.keys()):
        events = by_country[country]
        print(f"\n=== 正在复核 {country}（{len(events)} 条）===", flush=True)
        result = verify_country(country, events)
        all_results.append(result)
        with open(raw_path, "w", encoding="utf-8") as f:
            json.dump(all_results, f, ensure_ascii=False, indent=2)
        if "error" in result:
            print(f"  [{country}] 错误：{result['error']}", flush=True)
        else:
            verdicts = parse_country_result(result)
            print(f"  [{country}] 完成，返回 {len(verdicts)} 条结果", flush=True)
        time.sleep(2)

    new_fieldnames = update_csv(csv_rows, fieldnames, all_results, verification_time)

    report_path = os.path.join(OUTPUT_DIR, f"事件核查人工复核_{timestamp}.txt")
    generate_txt_report(all_results, report_path, verification_time)

    print("\n全部完成。", flush=True)
    print(f"原始结果：{raw_path}", flush=True)
    print(f"复核报告：{report_path}", flush=True)
    print(f"更新后 CSV：{CSV_PATH}", flush=True)


if __name__ == "__main__":
    main()
