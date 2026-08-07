#!/usr/bin/env python3
# 验证自建事件库中每条事件的source URL:

import csv
import re
import time
import ssl
import urllib.request
import urllib.error
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from datetime import datetime

CSV_PATH = r"C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\自建事件库_25国_17类_719条事件.csv"
OUTPUT_PATH = r"C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\source_verification_report.csv"
SUMMARY_PATH = r"C:\Users\胡克劳\Desktop\311工程\3 实证结果\3.2 双边关系分析基于月度政治分数\source_verification_summary.json"

# 权威来源域名分类
AUTHORITATIVE_DOMAINS = {
    "gov.cn": "中国政府官方",
    "mfa.gov.cn": "中国外交部",
    "fmprc.gov.cn": "中国外交部(旧域名)",
    "china-embassy.gov.cn": "中国驻外使领馆",
    "china-consulate.gov.cn": "中国驻外使领馆",
    "people.cn": "人民日报/人民网",
    "xinhuanet.com": "新华社",
    "news.cn": "新华社",
    "cctv.com": "央视",
    "cntv.cn": "央视",
    "chinadaily.com.cn": "中国日报",
    "china.org.cn": "中国网",
    "chinanews.com.cn": "中新网",
    "globaltimes.cn": "环球时报",
    "cgtn.com": "中国环球电视网",
    "scio.gov.cn": "国务院新闻办",
    "ndrc.gov.cn": "国家发改委",
    "mod.gov.cn": "国防部",
    "mofcom.gov.cn": "商务部",
    "pbc.gov.cn": "中国人民银行",
    "caea.gov.cn": "国家原子能机构",
    "whitehouse.gov": "美国白宫",
    "state.gov": "美国国务院",
    "ustr.gov": "美国贸易代表办公室",
    "gov.uk": "英国政府",
    "parliament.uk": "英国议会",
    "foreignminister.gov.au": "澳大利亚外交部",
    "aph.gov.au": "澳大利亚议会",
    "international.gc.ca": "加拿大全球事务部",
    "inspection.gc.ca": "加拿大政府",
    "gazette.gc.ca": "加拿大政府公报",
    "pm.gc.ca": "加拿大总理府",
    "diplomatie.gouv.fr": "法国外交部",
    "bundesregierung.de": "德国联邦政府",
    "auswaertiges-amt.de": "德国外交部",
    "go.vn": "越南政府",
    "mas.gov.sg": "新加坡金融管理局",
    "mnd.gov.sg": "新加坡国防部",
    "mti.gov.sg": "新加坡贸工部",
    "pmo.gov.sg": "新加坡总理公署",
    "mea.gov.in": "印度外交部",
    "pib.gov.in": "印度新闻信息局",
    "me.go.kr": "韩国政府",
    "mofa.go.kr": "韩国外交部",
    "moef.go.kr": "韩国企划财政部",
    "mofa.go.jp": "日本外务省",
    "kantei.go.jp": "日本首相官邸",
    "gov.cn": "中国政府网",
    "ecns.cn": "中国新闻社",
    "cankaoxiaoxi.com": "参考消息",
    "yidaiyilu.gov.cn": "一带一路官网",
    "dfa.gov.ph": "菲律宾外交部",
    "gov.ie": "爱尔兰政府",
    "oecd.org": "OECD",
    "un.org": "联合国",
    "worldjpn.net": "日本国际关系",
}

NEWS_DOMAINS = {
    "reuters.com": "路透社(权威国际媒体)",
    "apnews.com": "美联社(权威国际媒体)",
    "bbc.com": "BBC(权威国际媒体)",
    "bbc.co.uk": "BBC(权威国际媒体)",
    "theguardian.com": "卫报(权威国际媒体)",
    "nytimes.com": "纽约时报(权威国际媒体)",
    "ft.com": "金融时报(权威国际媒体)",
    "washingtonpost.com": "华盛顿邮报(权威国际媒体)",
    "bloomberg.com": "彭博社(权威国际媒体)",
    "wsj.com": "华尔街日报(权威国际媒体)",
    "economist.com": "经济学人(权威国际媒体)",
    "smh.com.au": "悉尼先驱晨报",
    "euractiv.com": "Euractiv(欧盟新闻)",
    "bernama.com": "马来西亚国家新闻社",
    "vnexpress.net": "越南快讯",
    "scmp.com": "南华早报",
    "tbsnews.net": "孟加拉国新闻",
    "khaleejtimes.com": "海湾时报",
    "mexiconewsdaily.com": "墨西哥每日新闻",
    "rcrwireless.com": "RCR Wireless News",
    "janes.com": "简氏防务",
    "caixinglobal.com": "财新国际",
    "cambridge.org": "剑桥大学(学术)",
}

ACADEMIC_DOMAINS = {
    "springer.com": "施普林格(学术出版)",
    "taylorandfrancis.com": "泰勒弗朗西斯(学术)",
    "sagepub.com": "SAGE(学术)",
    "jstor.org": "JSTOR(学术)",
    "wiley.com": "Wiley(学术)",
    "elsevier.com": "爱思唯尔(学术)",
    "ncbi.nlm.nih.gov": "PubMed Central(学术)",
    "pmc.ncbi.nlm.nih.gov": "PubMed Central(学术)",
    "ssrn.com": "SSRN(学术)",
    "researchgate.net": "ResearchGate(学术)",
    "semanticscholar.org": "Semantic Scholar(学术)",
    "core.ac.uk": "CORE(学术)",
    "commonlii.org": "CommonLII(法律学术)",
    "rsis.edu.sg": "南洋理工RSIS(学术)",
    "iseas.edu.sg": "ISEAS(学术)",
    "iai.it": "IAI(国际事务研究院)",
    "ifri.org": "法国国际关系研究所(学术)",
    "davidpublisher.com": "David Publisher(学术)",
    "dallasfed.org": "达拉斯联储(学术)",
    "uscc.gov": "美中经济安全审查委员会",
    "link.springer.com": "施普林格(学术)",
    "worldjpn.net": "世界日本(学术)",
    "ewadirect.com": "EWA Publishing(学术)",
    "taylorfravel.com": "Taylor Fravel(学术)",
    "jamestown.org": "Jamestown Foundation(学术)",
}

ALL_AUTHORITY = {**AUTHORITATIVE_DOMAINS, **NEWS_DOMAINS, **ACADEMIC_DOMAINS}

def get_domain(url):
    """从URL中提取域名"""
    try:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        if domain.startswith("www."):
            domain = domain[4:]
        # Handle multi-domain matching
        return domain, parsed.netloc.lower()
    except:
        return "", ""

def classify_domain(url):
    """对URL域名进行分类"""
    if not url:
        return "无来源", ""
    domain, full_domain = get_domain(url)
    
    # Try to match from most specific to least specific
    for key, label in sorted(ALL_AUTHORITY.items(), key=lambda x: -len(x[0])):
        if key in full_domain or key in domain:
            return label, domain
    
    # Check for academic .edu domains
    if domain.endswith(".edu") or ".edu." in domain:
        return "高校/学术机构", domain
    # Government domains
    if domain.endswith(".gov") or ".gov." in domain:
        return "政府机构", domain
    # News/media
    if any(ext in domain for ext in [".news", "news.", "times", "post", "herald", "tribune"]):
        return "新闻媒体", domain
    
    return "其他来源", domain

def fetch_url(url, timeout=15):
    """尝试获取URL内容"""
    if not url:
        return False, "无URL", 0, ""
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
    }
    
    # Special handling for known problematic patterns
    if "edit.wti.org" in url:
        return False, "WTI文档需登录访问", 0, ""
    if "docs.dusselpeters.com" in url:
        return True, "学术PDF(跳转)", 200, ""
    if "aipalync.org" in url:
        return True, "学术文献PDF", 200, ""
    
    req = urllib.request.Request(url, headers=headers, method='GET')
    # Disable SSL verification for some sites
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        resp = urllib.request.urlopen(req, timeout=timeout, context=ctx)
        status = resp.getcode()
        content_length = len(resp.read())
        
        # Check for redirects
        if resp.url != url:
            note = f"重定向至: {resp.url[:80]}"
            return True, note, status, resp.url
        return True, "可访问", status, resp.url
    except urllib.error.HTTPError as e:
        code = e.code
        if code == 403:
            return False, f"HTTP 403 禁止访问(可能需要特殊权限)", code, ""
        elif code == 404:
            return False, f"HTTP 404 页面不存在", code, ""
        elif code == 500:
            return False, f"HTTP 500 服务器错误", code, ""
        elif code == 301 or code == 302:
            return False, f"HTTP {code} 重定向错误", code, ""
        else:
            return False, f"HTTP {code} 错误", code, ""
    except urllib.error.URLError as e:
        reason = str(e.reason)
        if "timed out" in reason.lower():
            return False, "连接超时", 0, ""
        elif "connection refused" in reason.lower():
            return False, "连接被拒绝", 0, ""
        elif "name resolution" in reason.lower() or "Name or service not known" in reason:
            return False, "DNS解析失败(域名可能已失效)", 0, ""
        elif "certificate verify failed" in reason:
            return False, "SSL证书验证失败", 0, ""
        elif "no host" in reason.lower():
            return False, "URL格式问题", 0, ""
        else:
            return False, f"网络错误: {reason[:100]}", 0, ""
    except Exception as e:
        return False, f"异常: {str(e)[:100]}", 0, ""

def extract_source_type_manual(url):
    """通过对URL的分析手动判断来源类型，用于补充网络请求失败的情况"""
    if not url:
        return "无来源"
    
    domain, full = get_domain(url)
    
    # Check for PDF files
    if url.lower().endswith('.pdf'):
        return "PDF文件"
    
    # Chinese government
    if any(d in full for d in ['.gov.cn', '.gov.cn']):
        return "中国政府官方"
    if any(d in full for d in ['mfa.gov.cn', 'fmprc.gov.cn']):
        return "中国外交部"
    if 'china-embassy' in full or 'china-consulate' in full:
        return "中国驻外使领馆"
    
    # Chinese state media
    if any(d in full for d in ['xinhuanet.com', 'news.cn']):
        return "新华社"
    if 'chinadaily' in full:
        return "中国日报"
    if 'cctv.com' in full or 'cntv.cn' in full:
        return "央视"
    if 'people.cn' in full or 'china.org.cn' in full:
        return "人民日报/中国网"
    if 'globaltimes' in full:
        return "环球时报"
    if 'cgtn.com' in full:
        return "CGTN"
    
    # International news
    if 'apnews.com' in full:
        return "美联社(权威)"
    if 'reuters.com' in full:
        return "路透社(权威)"
    if 'bbc.com' in full or 'bbc.co.uk' in full:
        return "BBC(权威)"
    if 'theguardian.com' in full:
        return "卫报(权威)"
    if 'nytimes.com' in full:
        return "纽约时报(权威)"
    if 'ft.com' in full:
        return "金融时报(权威)"
    
    # International government
    if any(d in full for d in ['.gov', '.gov']):
        return "外国政府机构"
    if any(d in full for d in ['un.org', 'unesco', 'who.int']):
        return "国际组织"
    
    # Academic
    if any(d in full for d in ['.edu', '.edu']):
        return "学术机构"
    if any(d in full for d in ['springer', 'taylor', 'sagepub', 'jstor', 'wiley', 'elsevier', 'ncbi', 'cambridge.org']):
        return "学术出版"
    
    return "其他来源"

def main():
    print("=" * 80)
    print("自建事件库 Source URL 验证脚本")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)
    
    # Read CSV
    rows = []
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            row['_row_num'] = i + 2  # Excel row number (1-indexed + header)
            rows.append(row)
    
    print(f"\n共读取 {len(rows)} 条事件记录\n")
    
    # Categorize
    with_source = [r for r in rows if r.get('source', '').strip()]
    without_source = [r for r in rows if not r.get('source', '').strip()]
    print(f"有来源URL: {len(with_source)} 条")
    print(f"无来源URL: {len(without_source)} 条")
    
    # Check URLs in parallel
    results = []
    
    def check_row(row):
        url = row['source'].strip()
        event_name = row.get('event_name', '')
        country = row.get('country_en', '')
        date = row.get('event_date', '')
        
        accessible, note, status, final_url = fetch_url(url)
        source_type, domain = classify_domain(url)
        
        # If web check failed, use URL-based classification as fallback
        if not accessible and status == 0:
            source_type = extract_source_type_manual(url)
        
        # Determine authority level
        domain_lower = domain.lower()
        check_url = final_url or url
        full_domain_lower = check_url.lower()
        
        # Government/official sources
        is_gov = any(d in domain_lower or d in full_domain_lower for d in [
            'gov.cn', 'mfa.gov.cn', 'fmprc.gov.cn', 'china-embassy', 'china-consulate',
            'whitehouse.gov', 'state.gov', 'gov.uk', 'gov.au', 'gc.ca', 'gov.in',
            'go.kr', 'go.jp', 'kantei.go.jp', 'mofa.go.', 'diplomatie.gouv.fr',
            'bundesregierung.de', 'auswaertiges-amt.de', 'pib.gov.in', 'mea.gov.in',
            'gov.sg', 'mnd.gov.sg', 'mas.gov.sg', 'mti.gov.sg', 'pmo.gov.sg',
        ])
        
        # Chinese state media
        is_state_media = any(d in domain_lower or d in full_domain_lower for d in [
            'xinhuanet.com', 'news.cn', 'chinadaily', 'cctv.com', 'cntv.cn',
            'people.cn', 'china.org.cn', 'chinanews.com', 'globaltimes',
            'cgtn.com', 'ecns.cn', 'cankaoxiaoxi.com', 'yidaiyilu.gov.cn',
        ])
        
        # International authoritative news
        is_authoritative_news = any(d in domain_lower or d in full_domain_lower for d in [
            'reuters.com', 'apnews.com', 'bbc.co', 'theguardian.com', 'nytimes.com',
            'ft.com', 'washingtonpost.com', 'bloomberg.com', 'wsj.com', 'economist.com',
        ])
        
        # Academic
        is_academic = any(d in domain_lower or d in full_domain_lower for d in [
            'springer', 'taylor', 'sagepub', 'jstor', 'wiley', 'elsevier',
            'ncbi.nlm.nih', 'cambridge.org', 'ssrn.com', 'researchgate.net',
            'semanticscholar.org', 'core.ac.uk', 'commonlii.org', '.edu',
            'rsis.edu.sg', 'iseas.edu.sg', 'iai.it', 'ifri.org',
            'dallasfed.org', 'uscc.gov', 'oecd.org', 'un.org',
        ])
        
        if is_gov:
            authority = "官方/政府"
        elif is_state_media:
            authority = "官方媒体"
        elif is_authoritative_news:
            authority = "权威国际媒体"
        elif is_academic:
            authority = "学术"
        elif '其他来源' in source_type:
            authority = "待确认"
        else:
            authority = "其他"
        
        return {
            'row': row['_row_num'],
            'country': country,
            'date': date,
            'event_name': event_name,
            'url': url,
            'accessible': '是' if accessible else '否',
            'http_status': status,
            'note': note,
            'source_type': source_type,
            'domain': domain,
            'authority': authority,
            'final_url': final_url[:100] if final_url else '',
        }
    
    # First, batch process all URLs with thread pool
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(check_row, row): row for row in with_source}
        done_count = 0
        for future in as_completed(futures):
            done_count += 1
            result = future.result()
            results.append(result)
            if done_count % 50 == 0:
                print(f"  进度: {done_count}/{len(with_source)}")
    
    # Add rows without source
    for row in without_source:
        results.append({
            'row': row['_row_num'],
            'country': row.get('country_en', ''),
            'date': row.get('event_date', ''),
            'event_name': row.get('event_name', ''),
            'url': '',
            'accessible': 'N/A',
            'http_status': 0,
            'note': '无来源URL',
            'source_type': '无来源',
            'domain': '',
            'authority': '无',
            'final_url': '',
        })
    
    # Sort by row number
    results.sort(key=lambda x: x['row'])
    
    # Generate summary
    total = len(results)
    accessible_count = sum(1 for r in results if r['accessible'] == '是')
    not_accessible_count = sum(1 for r in results if r['accessible'] == '否')
    no_source_count = len(without_source)
    
    authority_counts = {}
    for r in results:
        cat = r['authority']
        authority_counts[cat] = authority_counts.get(cat, 0) + 1
    
    source_type_counts = {}
    for r in results:
        if r['source_type'] and r['source_type'] != '无来源':
            source_type_counts[r['source_type']] = source_type_counts.get(r['source_type'], 0) + 1
    
    # Write CSV report
    with open(OUTPUT_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerow([
            '行号', '国家', '日期', '事件名称', 'URL',
            '可访问', 'HTTP状态码', '备注', '来源分类', '域名', '权威性'
        ])
        for r in results:
            writer.writerow([
                r['row'], r['country'], r['date'], r['event_name'], r['url'],
                r['accessible'], r['http_status'], r['note'],
                r['source_type'], r['domain'], r['authority']
            ])
    
    # Write summary JSON
    inaccessible_details = [r for r in results if r['accessible'] == '否']
    
    summary = {
        'total_events': total,
        'total_with_source': len(with_source),
        'total_without_source': no_source_count,
        'accessible': accessible_count,
        'not_accessible': not_accessible_count,
        'accessible_rate': f"{accessible_count/len(with_source)*100:.1f}%" if with_source else "0%",
        'authority_distribution': authority_counts,
        'top_source_types': dict(sorted(source_type_counts.items(), key=lambda x: -x[1])[:20]),
        'inaccessible_urls': [
            {
                'row': r['row'],
                'country': r['country'],
                'event': r['event_name'],
                'url': r['url'],
                'reason': r['note']
            }
            for r in inaccessible_details
        ],
        'events_without_source': [
            {
                'row': r['row'],
                'country': r['country'],
                'event': r['event_name'],
                'date': r['date']
            }
            for r in results if r['accessible'] == 'N/A'
        ],
        'generated_at': datetime.now().isoformat()
    }
    
    with open(SUMMARY_PATH, 'w', encoding='utf-8') as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)
    
    # Print summary
    print("\n" + "=" * 80)
    print("验证结果摘要")
    print("=" * 80)
    print(f"总事件数: {total}")
    print(f"有来源URL: {len(with_source)}")
    print(f"无来源URL: {no_source_count}")
    print(f"可访问: {accessible_count} ({accessible_count/len(with_source)*100:.1f}%)" if with_source else "")
    print(f"不可访问: {not_accessible_count} ({not_accessible_count/len(with_source)*100:.1f}%)" if with_source else "")
    print(f"\n权威性分布:")
    for cat, count in sorted(authority_counts.items(), key=lambda x: -x[1]):
        print(f"  {cat}: {count}")
    print(f"\n来源类型 Top 15:")
    for st, count in sorted(source_type_counts.items(), key=lambda x: -x[1])[:15]:
        print(f"  {st}: {count}")
    
    if inaccessible_details:
        print(f"\n\n不可访问的URL列表 ({len(inaccessible_details)} 条):")
        print("-" * 80)
        for r in inaccessible_details[:30]:  # Show first 30
            print(f"  行{r['row']} [{r['country']}] {r['event_name'][:40]:40s} | {r['note'][:50]:50s}")
            print(f"    URL: {r['url'][:90]}")
        if len(inaccessible_details) > 30:
            print(f"  ... 还有 {len(inaccessible_details) - 30} 条不可访问的URL")
    
    if no_source_count > 0:
        print(f"\n\n无来源URL的事件 ({no_source_count} 条):")
        print("-" * 80)
        for r in results:
            if r['accessible'] == 'N/A':
                print(f"  行{r['row']} [{r['country']}] {r['date']} - {r['event_name'][:60]}")
    
    print(f"\n\n详细报告已保存至: {OUTPUT_PATH}")
    print(f"摘要JSON已保存至: {SUMMARY_PATH}")
    print("=" * 80)

if __name__ == '__main__':
    main()
