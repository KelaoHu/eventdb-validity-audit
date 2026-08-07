# -*- coding: utf-8 -*-
# Patch Australia 2012-09 APEC bilateral meeting to Verified based on gov.cn source.

import json

RAW_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events\verification_focus_raw_20260617_201151.json"

with open(RAW_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

for country_block in data:
    if country_block.get("country") == "Australia":
        raw_str = country_block.get("raw", "")
        parsed = json.loads(raw_str)
        for item in parsed.get("results", []):
            if item.get("event_name") == "Bilateral meeting on sidelines of APEC summit" and item.get("original_month") == "2012-09":
                item["verdict"] = "Verified"
                item["corrected_month"] = "2012-09"
                item["visit_direction"] = "third_party_meeting"
                item["visit_level"] = "state_head"
                item["visit_category"] = "third_party_meeting"
                item["source_url"] = "http://www.gov.cn/ldhd/2012-09/08/content_2219541.htm"
                item["notes"] = "\u4e2d\u56fd\u653f\u5e9c\u7f51\u8bc1\u5b9e\uff0c\u80e1\u9526\u6d9b\u4e3b\u5e2d\u4e8e2012\u5e749\u67088\u65e5\u5728\u4f5b\u62c9\u8fea\u6c83\u65af\u6258\u514bAPEC\u4f1a\u8bae\u671f\u95f4\u4e0e\u6fb3\u5927\u5229\u4e9a\u603b\u7406\u5409\u62c9\u5fb7\u4f1a\u6653\u3002"
                print("Patched Australia 2012-09 to Verified")
                break
        country_block["raw"] = json.dumps(parsed, ensure_ascii=False)
        break

with open(RAW_PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Raw file saved.")
