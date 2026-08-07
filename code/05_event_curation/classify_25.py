# -*- coding: utf-8 -*-
# classify_25.py

import csv
import re
import sys
import json
from pathlib import Path
from collections import Counter, defaultdict

BASE_DIR = Path(__file__).parent.parent.resolve()
SOURCE_CSV = Path(r'C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/批量事件图（25国）/data/events/all_events_in_plots.csv')
CLASS14_CSV = Path(r'C:/Users/胡克劳/Desktop/311工程/3 实证结果/3.2 双边关系分析基于月度政治分数/事件研究法（14国）/data/classification/14国事件分类(17类).csv')
OUT_DIR = BASE_DIR / 'data' / 'classification'
OUT_CSV = OUT_DIR / '25国事件分类(17类).csv'
REPORT_TXT = OUT_DIR / '_mapping_25.txt'
REVIEW_CSV = OUT_DIR / '_needs_web_review.csv'

ORIGINAL_14 = {
    "United States", "Japan", "Philippines", "Vietnam", "United Kingdom",
    "Australia", "India", "Canada", "South Korea", "Indonesia",
    "France", "Singapore", "Germany", "Italy"
}

CATEGORIES = [
    {'cn': '高层互访', 'en': 'High-level visit', 'valence': '积极'},
    {'cn': '战略伙伴关系提升', 'en': 'Strategic partnership upgrade', 'valence': '积极'},
    {'cn': '经贸互利合作', 'en': 'Economic win-win cooperation', 'valence': '积极'},
    {'cn': '人文交流合作', 'en': 'Cultural / people-to-people cooperation', 'valence': '积极'},
    {'cn': '军事安全合作', 'en': 'Military / security cooperation', 'valence': '积极'},
    {'cn': '疫情/危机援助', 'en': 'Pandemic / crisis aid', 'valence': '积极'},
    {'cn': '多边/第三方会晤', 'en': 'Multilateral / third-party meeting', 'valence': '中性'},
    {'cn': '远程通话/视频会晤', 'en': 'Remote talk / virtual meeting', 'valence': '中性'},
    {'cn': '外交抗议/摩擦', 'en': 'Diplomatic protest / friction', 'valence': '消极'},
    {'cn': '人员扣押/司法争议', 'en': 'Detention / judicial dispute', 'valence': '消极'},
    {'cn': '战略定位负面', 'en': 'Negative strategic positioning', 'valence': '消极'},
    {'cn': '政策转向/国内政治', 'en': 'Policy shift / domestic politics', 'valence': '消极'},
    {'cn': '主权纠纷', 'en': 'Sovereignty dispute', 'valence': '消极'},
    {'cn': '经贸制裁/关税壁垒', 'en': 'Economic sanction / tariff barrier', 'valence': '消极'},
    {'cn': '科技管制/出口限制', 'en': 'Tech control / export restriction', 'valence': '消极'},
    {'cn': '安全威胁', 'en': 'Security threat', 'valence': '消极'},
    {'cn': '疫情/灾害冲击', 'en': 'Pandemic / disaster shock', 'valence': '消极'},
]
CAT_BY_CN = {c['cn']: c for c in CATEGORIES}

# 对启发式分类中明显错误的边界案例进行人工校正（基于公开资料与事件语义判断）
CORRECTIONS = {
    ('Belgium', '2014-03', 'China-Belgium industrial investment fund agreement signed'): '经贸互利合作',
    ('Brazil', '2004-05', 'COSBAN established'): '战略伙伴关系提升',
    ('Brazil', '2006-03', 'First COSBAN Plenary Session held'): '战略伙伴关系提升',
    ('Brazil', '2013-12', 'CBERS-3 satellite launch failure'): '科技管制/出口限制',
    ('Iran', '2015-07', 'Joint Comprehensive Plan of Action (JCPOA) signed'): '经贸互利合作',
    ('Iran', '2023-03', 'China-brokered Saudi-Iran rapprochement restores diplomatic ties'): '战略伙伴关系提升',
    ('Malaysia', '2018-07', 'Malaysia suspends China-backed East Coast Rail Link project'): '政策转向/国内政治',
    ('Malaysia', '2024-06', 'Joint Statement on Deepening Comprehensive Strategic Partnership towards Community with Shared Future'): '战略伙伴关系提升',
    ('Mexico', '2007-02', 'Mexico requests WTO panel on Chinese industrial subsidy programs'): '经贸制裁/关税壁垒',
    ('Mexico', '2014-11', 'Mexico cancels USD 3.7 billion Chinese-led bullet train contract'): '政策转向/国内政治',
    ('Mexico', '2022-04', "Mexico amends Mining Law to nationalize lithium, affecting Ganfeng concessions"): '政策转向/国内政治',
    ('Russia', '2004-10', 'Supplementary agreement on China-Russia eastern border signed'): '战略伙伴关系提升',
    ('Russia', '2006-01', 'Russia Year in China launched'): '人文交流合作',
    ('Russia', '2008-10', 'Heixiazi Island handover and border marker unveiling'): '战略伙伴关系提升',
    ('Saudi Arabia', '2008-05', 'Saudi Arabia donates over US$60 million for Wenchuan earthquake relief'): '疫情/危机援助',
    ('Saudi Arabia', '2015-09', 'Mina Hajj stampede kills Chinese pilgrims'): '疫情/灾害冲击',
    ('Saudi Arabia', '2020-03', 'COVID-19 pandemic and oil price war slash China oil demand'): '疫情/灾害冲击',
    ('Saudi Arabia', '2025-05', 'China launches unilateral visa-free trial for Saudi citizens'): '经贸互利合作',
    ('Thailand', '2023-10', 'Thailand postpones Chinese S26T submarine project over engine dispute'): '政策转向/国内政治',
    ('United Arab Emirates', '2008-04', 'China-UAE criminal judicial assistance treaty signed'): '经贸互利合作',
    ('United Arab Emirates', '2017-02', 'CNPC awarded 8% stake in Abu Dhabi onshore oil concession'): '经贸互利合作',
}


def classify_by_rules(r):
    """对新增 11 国事件做启发式分类，返回 (category_cn, confidence, reason)。"""
    name = str(r.get('event_name', '')).lower()
    et = str(r.get('event_type', '')).lower()
    impact = str(r.get('impact', '')).lower()
    vd = str(r.get('visit_direction', '')).lower()
    vc = str(r.get('visit_category', '')).lower()

    # 领导人相关事件
    if et == 'leader_visit':
        if 'remote_talk' in vc or 'remote' in name or 'phone call' in name or 'video' in name:
            return '远程通话/视频会晤', 'high', 'leader_visit + remote talk marker'
        if 'third_party' in vd or 'third_party' in vc or 'summit' in name or 'apec' in name or 'g20' in name or 'asean' in name:
            return '多边/第三方会晤', 'high', 'leader_visit + third-party/multilateral marker'
        return '高层互访', 'high', 'leader_visit default'

    # 文化类
    if et == 'cultural':
        return '人文交流合作', 'high', 'event_type cultural'

    # 正面疫情
    if et == 'pandemic' and impact == 'positive':
        return '疫情/危机援助', 'high', 'pandemic positive'

    # 负面疫情 / 灾害
    if et == 'pandemic' and impact == 'negative':
        return '疫情/灾害冲击', 'high', 'pandemic negative'

    # 制裁 / 关税壁垒
    if et == 'sanctions' or any(k in name for k in ['sanction', 'tariff', 'anti-dumping', 'countervailing duty', 'duties on', 'ban ', 'bans ']):
        # 科技管制更具体
        if any(k in name for k in ['5g', 'huawei', 'zte', 'semiconductor', 'export control', 'chip', 'dual-use', 'tech']):
            return '科技管制/出口限制', 'medium', 'sanctions/tech keywords'
        return '经贸制裁/关税壁垒', 'medium', 'sanctions/tariff keywords'

    # 科技管制
    if et == 'policy' and any(k in name for k in ['5g', 'huawei', 'zte', 'semiconductor', 'export control', 'cybersecurity', 'tech']):
        return '科技管制/出口限制', 'medium', 'policy + tech keywords'

    # 人员扣押 / 司法
    if any(k in name for k in ['detain', 'arrest', 'judicial', 'court', 'trial', 'sentenced', 'prison', 'espionage', 'spying']):
        return '人员扣押/司法争议', 'medium', 'detention/judicial keywords'

    # 主权纠纷 / 领土
    if et in {'territorial', 'border_standoff'} or any(k in name for k in ['south china sea', 'scs', 'diaoyu', 'senkaku', 'natuna', 'border', 'territorial', 'sovereignty', 'arbitration', 'adiz', 'galwan', 'doklam']):
        return '主权纠纷', 'medium', 'territorial/sovereignty keywords'

    # 安全威胁 / 军事
    if et in {'military', 'crisis'} or any(k in name for k in ['military', 'defense', 'threat', 'attack', 'drill', 'exercise', 'deployment', 'aukus', 'thaad', 'base', 'missile', 'nuclear', 'clash', 'standoff', 'war']):
        # 军事合作（积极）vs 安全威胁（消极）
        if impact == 'positive' or any(k in name for k in ['cooperation', 'joint', 'drill', 'exercise', 'patrol', 'handover']):
            return '军事安全合作', 'medium', 'military + positive/cooperation marker'
        return '安全威胁', 'medium', 'military/security negative'

    # 外交抗议 / 摩擦
    if et == 'diplomatic' and impact == 'negative':
        return '外交抗议/摩擦', 'medium', 'diplomatic negative'

    # 战略伙伴关系提升
    if et == 'strategic' or any(k in name for k in ['strategic partnership', 'comprehensive strategic', 'community with shared future', 'joint statement', 'action plan', 'joint communique']):
        if impact == 'negative':
            return '战略定位负面', 'medium', 'strategic but negative'
        return '战略伙伴关系提升', 'medium', 'strategic/partnership keywords'

    # 经贸互利合作
    if et == 'economic':
        if impact == 'negative':
            # 进一步区分：制裁类已在上面，这里是负面经济事件如合同取消
            if any(k in name for k in ['cancel', 'suspend', 'nationalize', 'seize', 'delay', 'postpone']):
                return '经贸制裁/关税壁垒', 'low', 'negative economic, possible sanction/dispute'
            return '经贸互利合作', 'low', 'economic negative default'
        return '经贸互利合作', 'medium', 'economic positive default'

    # 政策转向
    if et == 'policy':
        return '政策转向/国内政治', 'medium', 'event_type policy'

    # 外交 positive 默认
    if et == 'diplomatic' and impact == 'positive':
        return '经贸互利合作', 'low', 'diplomatic positive default'

    # fallback
    if impact == 'negative':
        return '外交抗议/摩擦', 'low', 'fallback negative'
    return '经贸互利合作', 'low', 'fallback positive/neutral'


def validate_valence(impact, valence):
    if impact == 'positive' and valence == '消极':
        return False
    if impact == 'negative' and valence == '积极':
        return False
    return True


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # 读取 25 国事件
    with open(SOURCE_CSV, 'r', encoding='utf-8-sig', newline='') as f:
        source_rows = list(csv.DictReader(f))
    source_rows = [r for r in source_rows if str(r.get('applies_to_main', '')).strip().upper() == 'TRUE']
    print(f'读取 25 国活跃事件: {len(source_rows)}')

    # 读取 14 国分类
    with open(CLASS14_CSV, 'r', encoding='utf-8-sig', newline='') as f:
        class14_rows = list(csv.DictReader(f))
    class14_map = {}
    for r in class14_rows:
        key = (r['country_en'], r['event_date'], r['event_name'])
        class14_map[key] = r
    print(f'读取 14 国分类: {len(class14_rows)}')

    results = {}
    needs_review = []
    for i, r in enumerate(source_rows):
        country = r['country_en']
        key = (country, r['yearmonth'], r['event_name'])
        if country in ORIGINAL_14 and key in class14_map:
            c = class14_map[key]
            results[i] = {
                'event_category': c['event_category'],
                'event_category_en': c['event_category_en'],
                'valence': c['valence'],
                'classification_basis': f"复用 14 国项目分类结果",
                'confidence': 'high',
            }
        else:
            cat_cn, conf, reason = classify_by_rules(r)
            key_corr = (r['country_en'], r['yearmonth'], r['event_name'])
            if key_corr in CORRECTIONS:
                cat_cn = CORRECTIONS[key_corr]
                conf = 'high'
                reason = '人工校正（基于公开资料与事件语义）'
            cat = CAT_BY_CN[cat_cn]
            results[i] = {
                'event_category': cat_cn,
                'event_category_en': cat['en'],
                'valence': cat['valence'],
                'classification_basis': f"启发式分类: {reason}",
                'confidence': conf,
            }
            if conf != 'high':
                needs_review.append({
                    'index': i,
                    'country_en': country,
                    'country_cn': r['country_cn'],
                    'yearmonth': r['yearmonth'],
                    'event_name': r['event_name'],
                    'event_type': r['event_type'],
                    'impact': r['impact'],
                    'proposed_category': cat_cn,
                    'confidence': conf,
                    'reason': reason,
                })

    # 构建输出
    fieldnames = [
        'country_en', 'event_name', 'event_date', 'event_type_original',
        'event_category', 'event_category_en', 'valence', 'classification_basis',
        'info_source', 'country_cn', 'impact', 'visit_level', 'visit_direction',
        'visit_category', 'visitor', 'host', 'location', 'source'
    ]
    out_rows = []
    conflict_count = 0
    for i, r in enumerate(source_rows):
        meta = results[i]
        if not validate_valence(r['impact'], meta['valence']):
            conflict_count += 1
        out_rows.append({
            'country_en': r['country_en'],
            'event_name': r['event_name'],
            'event_date': r['yearmonth'],
            'event_type_original': r['event_type'],
            'event_category': meta['event_category'],
            'event_category_en': meta['event_category_en'],
            'valence': meta['valence'],
            'classification_basis': meta['classification_basis'],
            'info_source': '新闻报道、政府声明及国际组织公开信息',
            'country_cn': r['country_cn'],
            'impact': r['impact'],
            'visit_level': r.get('visit_level', ''),
            'visit_direction': r.get('visit_direction', ''),
            'visit_category': r.get('visit_category', ''),
            'visitor': r.get('visitor', ''),
            'host': r.get('host', ''),
            'location': r.get('location', ''),
            'source': r.get('source', ''),
        })

    with open(OUT_CSV, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(out_rows)

    # 待复核清单
    if needs_review:
        with open(REVIEW_CSV, 'w', encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=list(needs_review[0].keys()))
            writer.writeheader()
            writer.writerows(needs_review)
        print(f'待复核事件: {len(needs_review)}')
    else:
        print('无待复核事件')

    # 报告
    counter = Counter(o['event_category'] for o in out_rows)
    with open(REPORT_TXT, 'w', encoding='utf-8-sig') as f:
        f.write('25 国事件分类报告（17 类）\n')
        f.write(f'来源文件: {SOURCE_CSV}\n')
        f.write(f'输出文件: {OUT_CSV}\n')
        f.write(f'总事件数: {len(out_rows)}\n')
        f.write(f'复用 14 国分类: {sum(1 for r in source_rows if r["country_en"] in ORIGINAL_14)}\n')
        f.write(f'启发式分类: {sum(1 for r in source_rows if r["country_en"] not in ORIGINAL_14)}\n')
        f.write(f'倾向冲突数: {conflict_count}\n')
        f.write(f'待复核数: {len(needs_review)}\n')
        f.write('\n分类统计:\n')
        for cat, cnt in counter.most_common():
            f.write(f'  {cnt:4d} | {cat}\n')

    print(f'已生成: {OUT_CSV}')
    print(f'总事件数: {len(out_rows)}, 冲突: {conflict_count}, 待复核: {len(needs_review)}')


if __name__ == '__main__':
    main()
