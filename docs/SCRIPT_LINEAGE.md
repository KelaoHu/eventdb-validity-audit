# Script Lineage（脚本版本沿革对照表）

终版依据作者工程总账（311工程全景梳理报告_20260802）逐一点名核对。版本号为作者迭代标记（非语义化版本），保留以展示工程过程。

## Acquisition（code/01_acquisition/）

| Repository file | 原始文件名 | 功能 |
|---|---|---|
| `gdelt/gdelt_download_zips_v4.12.py` | GDELT下载zip2000_2025_4.12.py | GDELT 事件 ZIP 全量下载（断点续跑/重试） |
| `gdelt/gdelt_retrieve_china_25partners_v4.14.py` | GDELT2002-2025——标定全体检索_4.14.py | ★终版：中国×25 国严格 dyad 检索（多进程） |
| `gdelt/cameo_event_codes.py` | GDELT_event codes.py | CAMEO 事件代码中英对照表 |
| `gdelt/gdelt_zip_coverage_check_v4.15.py` | 2002-2025文件查询_4.15.py | 本地下载覆盖完整性盘点 |
| `icews/icews_download_dataverse_v4.14.py` | ICEWS下载_2000_2025_4.14.py | ICEWS Dataverse 全量下载（pyDataverse） |
| `icews/icews_retrieve_25partners_v4.17.py` | ICEWS直接检索25国_4.17.py | ★终版：中国×25 国检索（下载检索一体） |
| `icews/icews_cameo_goldstein_codes.py` | ICEWS事件编码.py | ICEWS/CAMEO 编码 + Goldstein 分值 + Quad 分类表 |

## Aggregation（code/02_aggregation/）

| Repository file | 原始文件名 | 功能 |
|---|---|---|
| `geometric_mean_day_to_month_v5.23_GDELT.py` | 几何平均方法（由日到月）_5.23（2002-2025）GDELT.py | ★主线终版：几何平均（对数空间、+11、两阶段） |
| `three_db_five_algorithms_v6.3_optimized.py` | 三库五种算法综合分析_由日到月_6.3_优化版.py | ★终版：三库×5 算法、公平窗、跨库相关 |
| 其余 26 个脚本保留原名 | — | 算术/中位数/二次平均/绝对值加权/Z-Score/NumArticles 过滤等替代算法与稳健性实验 |

## Economic data（code/03_economic_data/）

| Repository file | 原始文件名 | 功能 |
|---|---|---|
| `imf_dots_bilateral_trade_v5.9.py` | IMF检索25个国家月度聚类2002.1-2025.12_5.9.py | ★终版：IMF DOTS 双边月度贸易（主） |
| `imf_imts_mirror_trade.py` | IMTS_伙伴国视角对华贸易下载_25国_月度_2002-2025.py | 伙伴国镜像视角校验 |
| `imf_qnea_gdp_monthly_interp.py` | IMF_QNEA_季度GDP下载_25国_月度插值_2002-2025.py | QNEA GDP + 月度插值（WB 补 UAE/越南） |
| `bis_imf_reer_26countries.py` | IMF_EER_REER有效汇率下载处理_26国含中国_月度_2002-2025.py | ★终版：BIS 主源 REER，26 国含中国 |
| `imf_er_exchange_rates.py` | IMF_ER_汇率下载_25国_月度_2002-2025.py | 名义汇率 |
| `comtrade_china_25partners_v5.7.py` | UN Comtrade检索2002-2025中国25贸易伙伴月度贸易额度_5.7.py | Comtrade 交叉验证 |
| `wto_rta_fta_dummies.py` | WTO_RTA_中国FTA检索下载_25国月度虚拟变量.py | FTA 月度虚拟变量（抓取+人工核实回退） |
| `sample_selection/cepii_baci_top30_2002_v5.9.py` | CEPII中国前30贸易伙伴2002BACI算法.5.9.py | 2002 期初选样依据（BACI） |
| `sample_selection/verify_top_partners_2002.py` / `verify_top_partners_2014_v4.8.py` | 检验2002/2014年中国贸易伙伴（复现_4.8）.py | 样本名单复现检验 |

## Panel & polling（code/04_panel/）

| Repository file | 原始文件名 | 功能 |
|---|---|---|
| `build_panel_with_lags.py` | 01_数据面板合并与滞后变量生成.py | ★终版：面板合并 + L0–L6 滞后 |
| `polling/` | 07_数据库与民调 工作区 | phase0_clean.py + E0–E5 + robustness.R + analysis.R 全链 |

## Event curation（code/05_event_curation/）

| Repository file | 功能 |
|---|---|
| `classify_25.py` / `apply_curation.py` / `create_verification_report.py` | ★收口链：17 类分类 → 新增 11 国精简（713→712）→ 逐条来源核查报告 |
| `verify_focus_events_api.py` + `extract_focus_events.py` + `complete_from_raw.py` + `clean_verification_report.py` + `patch_australia_*.py` | 104 条重点事件定向复核链（API + 联网搜索）+ 人工补丁 |
| `verify_sources.py` + `source_verification_report.csv` | 712 条逐条来源核查（外交部/官方媒体等 522 条官方源） |

## Analysis（code/06_analysis/）与 Figures（code/07_figures/）

- `ppml_suite/`、`event_study_suite/`（9 模块）、`revision_tests_202607/`（17 模块）、`19_sanction_observability/`、`20_full_ppml_tables/`、`rerun_fair_coverage_202607/`（canonical 重跑+对比总账）——保留原始目录与 README
- `fig01_v6_heatmap.R`（热力图版，2026-08-08 替代地图版）、`fig02_v3.R`–`fig06_v3.R`、`figS1–S3`、`00_theme_v4.R`——图件终版（v3 系列，QA 闸门内嵌）
