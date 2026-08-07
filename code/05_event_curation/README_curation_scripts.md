# 事件核查脚本集合（2025-06-17）

本文件夹集中存放 2025-06-17 当天为“批量事件图与事件研究法”项目编写的全部事件核查相关脚本、补丁与测试输出。

## 主流程脚本（推荐优先查看）

| 文件 | 说明 |
|------|------|
| `verify_focus_events_api.py` | **最终主脚本**：对 104 条重点事件使用 联网核查接口 + DuckDuckGo 联网搜索进行定向复核，生成中文 TXT 报告并更新 CSV。 |
| `extract_focus_events.py` | 从最终核查报告中提取 104 条需要重点复核的事件，并与 `all_events_in_plots.csv` 匹配。 |
| `complete_from_raw.py` | 从已保存的 raw JSON 直接完成 CSV 更新和报告生成，避免重复调用 API。 |
| `clean_verification_report.py` | 后处理复核 raw JSON：对因搜索失败被标记为 Needs Review 的事件，保留第一轮结论。 |
| `patch_australia_201104.py` | 人工修补 Australia 2011-04 官方访问事件结论。 |
| `patch_australia_201209.py` | 人工修补 Australia 2012-09 APEC 双边会晤事件结论。 |

## 探索/替代版本（已归档备用）

| 文件 | 说明 |
|------|------|
| `verify_events_online_final.py` | 联网核查接口两-pass 全量复核（预取搜索摘要版）。 |
| `verify_events_online_two_pass.py` | 联网核查接口两-pass 全量复核（实时搜索版）。 |
| `verify_events_fast.py` | 快速两-pass 全量复核（每事件一次搜索）。 |
| `verify_events_retry.py` | 第三轮针对性复核，专门处理 Unverifiable / Needs Review 事件。 |
| `verify_events_online.py` | 早期在线核查全量复核脚本。 |
| `verify_events_v2.py` | 更早的 v2 版本。 |

## 工具与测试

| 文件 | 说明 |
|------|------|
| `extract_docs.py` | 批量提取 `政治经济的冷与热科研` 目录下 Word 文档文本。 |
| `test_verify_australia.py` | 仅复核 Australia 事件的测试入口。 |
| `test_australia.py` | Australia 事件 API/搜索测试。 |
| `test_v4pro_json.py` | V4-Pro JSON 输出格式测试。 |
| `test_verification_tool.py` | 核查接口连接测试。 |
| `test_aus_result.json` | Australia 测试输出结果。 |
| `test_aus_result_fc.json` | Australia 测试输出结果（final/check）。 |

## 数据输入/输出路径

脚本中使用的目标数据文件通常位于：

```
C:\Users\胡克劳\Desktop\政治经济的冷与热科研\批量事件图与事件研究法\data\events\
```

主要文件：
- `all_events_in_plots.csv`：最终事件清单。
- `verification_focus_raw_20260617_201151.json`：最新一轮 API 复核原始输出。
- `事件核查人工复核_20260617_205416.txt`：最终中文复核报告。

## 使用建议

1. 若需重新跑完整复核，直接运行 `verify_focus_events_api.py`。
2. 若已有 raw JSON 只想重新生成报告/更新 CSV，运行 `complete_from_raw.py`。
3. 探索性脚本和测试脚本一般不再修改，仅作备份参考。
