# -*- coding: utf-8 -*-
# Patch Australia 2011-04 Official visit to Australia event in raw JSON.

import json
import re

RAW_PATH = r"C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events\verification_focus_raw_20260617_201151.json"

with open(RAW_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

for country_block in data:
    if country_block.get("country") == "Australia":
        raw_str = country_block.get("raw", "")
        # Replace the incorrect Verified entry for 2011-04 Official visit to Australia
        old_entry = r'{\s*"event_name":\s*"Official visit to Australia",\s*"original_month":\s*"2011-04",[^}]*"verdict":\s*"Verified"[^}]*}'
        new_entry = json.dumps({
            "event_name": "Official visit to Australia",
            "original_month": "2011-04",
            "verdict": "Major",
            "corrected_month": "2011-04",
            "corrected_event_name": "Official visit to China",
            "corrected_visitor": "Australian Prime Minister Julia Gillard",
            "corrected_host": "Chinese Premier Wen Jiabao",
            "corrected_location": "Beijing",
            "visit_direction": "partner_to_china",
            "visit_level": "government_head",
            "visit_category": "partner_govhead_to_china",
            "source_url": "https://china.embassy.gov.au/bjng/mrpm.html",
            "notes": "Australian Embassy in Beijing and Chinese Foreign Ministry confirm that Prime Minister Julia Gillard paid an official visit to China from April 25 to 27, 2011, at the invitation of Premier Wen Jiabao. The original record incorrectly described it as Wen Jiabao visiting Australia."
        }, ensure_ascii=False)
        new_raw_str, count = re.subn(old_entry, new_entry, raw_str)
        if count > 0:
            country_block["raw"] = new_raw_str
            print(f"Patched {count} entry for Australia 2011-04")
        else:
            print("No matching entry found; will try alternative matching")
            # Alternative: parse JSON, modify, re-serialize
            try:
                parsed = json.loads(raw_str)
                for item in parsed.get("results", []):
                    if item.get("event_name") == "Official visit to Australia" and item.get("original_month") == "2011-04":
                        item["verdict"] = "Major"
                        item["corrected_event_name"] = "Official visit to China"
                        item["corrected_visitor"] = "Australian Prime Minister Julia Gillard"
                        item["corrected_host"] = "Chinese Premier Wen Jiabao"
                        item["corrected_location"] = "Beijing"
                        item["visit_direction"] = "partner_to_china"
                        item["visit_level"] = "government_head"
                        item["visit_category"] = "partner_govhead_to_china"
                        item["source_url"] = "https://china.embassy.gov.au/bjng/mrpm.html"
                        item["notes"] = "Australian Embassy in Beijing and Chinese Foreign Ministry confirm that Prime Minister Julia Gillard paid an official visit to China from April 25 to 27, 2011, at the invitation of Premier Wen Jiabao. The original record incorrectly described it as Wen Jiabao visiting Australia."
                        print("Patched via JSON parse")
                        break
                country_block["raw"] = json.dumps(parsed, ensure_ascii=False)
            except Exception as e:
                print("Alternative patch failed:", e)
        break

with open(RAW_PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Raw file saved.")
