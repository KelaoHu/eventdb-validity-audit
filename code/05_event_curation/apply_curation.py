# -*- coding: utf-8 -*-
# Update all_events_in_plots.csv to keep only curated new-11 events.

from pathlib import Path
import pandas as pd, shutil, datetime

src_path = Path.home() / 'Desktop' / '311工程' / '3 实证结果' / '3.2 双边关系分析基于月度政治分数' / '批量事件图（25国）' / 'data' / 'events' / 'all_events_in_plots.csv'
keep_path = Path(__file__).parent / 'keep_new11_final.csv'

# Backup
backup = src_path.with_name(f'all_events_in_plots_backup_{datetime.datetime.now():%Y%m%d_%H%M%S}.csv')
shutil.copy2(src_path, backup)
print('backup', backup)

df = pd.read_csv(src_path)
keep = pd.read_csv(keep_path)
new_countries = set(keep.country_en)

# Correct the Netherlands ASML event date from 2023-03 to 2023-06 based on web verification
mask_nl = (df.country_en == 'Netherlands') & (df.event_name.str.contains('export controls on advanced semiconductor equipment', case=False, na=False))
if mask_nl.any():
    df.loc[mask_nl, 'yearmonth'] = '2023-06'
    df.loc[mask_nl, 'source'] = 'https://en.tmtpost.com/post/6689175'
    print('corrected Netherlands ASML event to 2023-06')

# Build key for keep
keep['_key'] = keep.country_en + '|' + keep.yearmonth + '|' + keep.event_name
df['_key'] = df.country_en + '|' + df.yearmonth + '|' + df.event_name

# Mark applies_to_main: original 14 unchanged, new 11 only if in keep
orig14 = {"United States", "Japan", "Philippines", "Vietnam", "United Kingdom",
          "Australia", "India", "Canada", "South Korea", "Indonesia",
          "France", "Singapore", "Germany", "Italy"}

def decide(row):
    if row.country_en in orig14:
        return row.applies_to_main
    return row._key in set(keep['_key'])

df['applies_to_main'] = df.apply(decide, axis=1)

# Summary
print('new countries total rows', len(df[df.country_en.isin(new_countries)]))
print('new countries applies True', (df[df.country_en.isin(new_countries)].applies_to_main == True).sum())
print('kept per country:')
print(df[df.applies_to_main == True].groupby('country_en').size().loc[sorted(new_countries)])

# Save
df.drop(columns=['_key']).to_csv(src_path, index=False, encoding='utf-8-sig')
print('saved', src_path)
