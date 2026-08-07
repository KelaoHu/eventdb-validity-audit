# 05_领导人会晤效应与双边关系（4 分类版）
# 数据: ../data/events_719.csv, ../data/scores_v3_GDELT_ICEWS_2025.csv
# 运行:
#   cd code && Rscript generate.R
#   cd ../robustness && Rscript generate_robustness.R
#
# 方法:
# 1. 从 713 条事件库中筛选 event_type_original == "leader_visit" 的领导人互动事件。
# 2. 将所有领导人互动归并为 4 类：
#    - Chinese outbound visit（中国领导人出访）: visit_direction == "china_to_partner"
#    - Partner inbound visit（外国领导人来访）: visit_direction == "partner_to_china"
#    - Third-party meeting（第三方/多边场合会谈）: visit_direction == "third_party_meeting"
#    - Remote talk（远程通话/视频）: event_category_en == "Remote talk / virtual meeting"
# 3. 不再区分国家元首（state_head）与政府首脑（government_head）。
# 4. 以事件发生前 3 个月的月度 Z-score 均值为基线，
#    计算事件后 0、1、2、3、6、12 个月的 Z-score 变化（shock）。
# 5. 分别对 GDELT 与 ICEWS 两个数据库进行计算。
#
# 主要输出:
#   code/results/leader_meeting_effects.csv      事件级冲击序列
#   code/results/direction_summary.csv           按 4 类汇总的即时冲击统计
#   code/results/category4_event_counts.csv      4 分类事件数
#   robustness/m5_robustness_category4.png       4 分类即时冲击柱状图
#   robustness/m5_robustness_category4.csv       4 分类统计量
#
# 旧版 6 分类结果已备份至 archive/old_6category_results_*/。
