from __future__ import annotations

import time
import zipfile
from pathlib import Path

import pandas as pd


# ============================================================
# 用户参数
# ============================================================

YEAR = 2002
TOP_N = 30

# 中国代码（UN Numeric）
CHINA_CODE = "156"

ZIP_PATH = Path(
    r"C:\Users\胡克劳\Desktop\科研经济数据库\CEPII_BACI\BACI_HS02_V202601.zip"
)

OUTPUT_DIR = Path(
    r"C:\Users\胡克劳\Desktop\科研经济数据库\CEPII_BACI"
)

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

OUTPUT_FILE = (
    OUTPUT_DIR /
    f"CEPII_BACI_China_Top{TOP_N}_{YEAR}_Clean.csv"
)


# ============================================================
# 删除对象
# ============================================================

EXCLUDE_KEYWORDS = [

    # 中国特殊地区
    "hong kong",
    "taiwan",
    "macao",
    "macau",

    # 聚合项
    "world",
    "areas, nes",
    "countries, nes",
    "special categories",
    "other asia",
    "other europe",
    "other africa",
    "other america",
    "other oceania",

    # 其他统计项
    "free zones",
    "ship stores",
    "bunkers",
    "high seas",

    # 大洲
    "asia",
    "africa",
    "europe",
    "americas",
    "oceania",

    # 组织
    "eu-27",
    "european union",

    # 未知
    "unknown",
]


# ============================================================
# 工具函数
# ============================================================

def locate_trade_file(names, year):

    for n in names:

        low = n.lower()

        if (
            f"y{year}" in low
            and "baci_hs02" in low
            and low.endswith(".csv")
        ):
            return n

    raise FileNotFoundError(
        f"未找到 {year} 年贸易文件"
    )


def locate_country_file(names):

    for n in names:

        low = n.lower()

        if (
            "country_codes" in low
            and low.endswith(".csv")
        ):
            return n

    raise FileNotFoundError(
        "未找到国家代码文件"
    )


def clean_country_name(name: str) -> bool:

    s = str(name).lower()

    for kw in EXCLUDE_KEYWORDS:

        if kw in s:
            return False

    return True


# ============================================================
# 主程序
# ============================================================

def main():

    print("=" * 72)
    print("CEPII BACI 中国 Top30 双边贸易伙伴")
    print("=" * 72)

    start_time = time.time()

    if not ZIP_PATH.exists():

        raise FileNotFoundError(
            f"\nZIP 不存在：\n{ZIP_PATH}"
        )

    print(f"\nZIP 文件：")
    print(ZIP_PATH)

    # ========================================================
    # 打开 ZIP
    # ========================================================

    with zipfile.ZipFile(ZIP_PATH, "r") as zf:

        names = zf.namelist()

        print(f"\nZIP 内文件数：{len(names)}")

        # ----------------------------------------------------
        # 文件定位
        # ----------------------------------------------------

        trade_file = locate_trade_file(
            names,
            YEAR
        )

        country_file = locate_country_file(
            names
        )

        print(f"\n贸易文件：{trade_file}")
        print(f"国家文件：{country_file}")

        # ====================================================
        # 读取国家表
        # ====================================================

        print("\n读取国家表...")

        with zf.open(country_file) as f:

            country_df = pd.read_csv(f)

        print(f"国家表行数：{len(country_df):,}")

        print("\n国家表字段：")
        print(country_df.columns.tolist())

        # ====================================================
        # 自动识别字段
        # ====================================================

        code_col = country_df.columns[0]
        name_col = country_df.columns[1]

        print(f"\n识别国家代码列：{code_col}")
        print(f"识别国家名称列：{name_col}")

        # 转字符串
        country_df[code_col] = (
            country_df[code_col]
            .astype(str)
            .str.strip()
        )

        country_df[name_col] = (
            country_df[name_col]
            .astype(str)
            .str.strip()
        )

        # 国家映射
        country_lookup = dict(
            zip(
                country_df[code_col],
                country_df[name_col]
            )
        )

        # ====================================================
        # 读取贸易数据
        # ====================================================

        print("\n读取贸易数据...")

        with zf.open(trade_file) as f:

            trade_df = pd.read_csv(
                f,
                usecols=["t", "i", "j", "v"]
            )

        print(f"贸易数据行数：{len(trade_df):,}")

        print("\n贸易数据预览：")
        print(trade_df.head())

        # ====================================================
        # 转字符串
        # ====================================================

        trade_df["i"] = (
            trade_df["i"]
            .astype(str)
            .str.strip()
        )

        trade_df["j"] = (
            trade_df["j"]
            .astype(str)
            .str.strip()
        )

        trade_df["v"] = pd.to_numeric(
            trade_df["v"],
            errors="coerce"
        )

        # ====================================================
        # 中国出口
        # ====================================================

        print("\n聚合中国出口...")

        export_df = (
            trade_df.loc[
                trade_df["i"] == CHINA_CODE
            ]
            .groupby("j", as_index=False)["v"]
            .sum()
            .rename(columns={
                "j": "partner_code",
                "v": "china_export"
            })
        )

        # ====================================================
        # 中国进口
        # ====================================================

        print("聚合中国进口...")

        import_df = (
            trade_df.loc[
                trade_df["j"] == CHINA_CODE
            ]
            .groupby("i", as_index=False)["v"]
            .sum()
            .rename(columns={
                "i": "partner_code",
                "v": "china_import"
            })
        )

        # ====================================================
        # 合并
        # ====================================================

        print("合并进出口...")

        bilateral_df = export_df.merge(
            import_df,
            on="partner_code",
            how="outer"
        )

        bilateral_df["china_export"] = (
            bilateral_df["china_export"]
            .fillna(0)
        )

        bilateral_df["china_import"] = (
            bilateral_df["china_import"]
            .fillna(0)
        )

        bilateral_df["china_trade_total"] = (
            bilateral_df["china_export"]
            +
            bilateral_df["china_import"]
        )

        # ====================================================
        # 国家名称映射
        # ====================================================

        bilateral_df["partner_code"] = (
            bilateral_df["partner_code"]
            .astype(str)
            .str.strip()
        )

        bilateral_df["partner_name"] = (
            bilateral_df["partner_code"]
            .map(country_lookup)
        )

        # ====================================================
        # 删除中国自己
        # ====================================================

        bilateral_df = bilateral_df.loc[
            bilateral_df["partner_code"] != CHINA_CODE
        ].copy()

        # ====================================================
        # 删除 aggregate entities
        # ====================================================

        print("\n删除 aggregate entities...")

        before_n = len(bilateral_df)

        bilateral_df = bilateral_df.loc[
            bilateral_df["partner_name"]
            .map(clean_country_name)
        ].copy()

        after_n = len(bilateral_df)

        print(f"删除前：{before_n}")
        print(f"删除后：{after_n}")
        print(f"删除数量：{before_n - after_n}")

        # ====================================================
        # 排序
        # ====================================================

        bilateral_df = bilateral_df.sort_values(
            "china_trade_total",
            ascending=False
        ).reset_index(drop=True)

        bilateral_df["rank"] = range(
            1,
            len(bilateral_df) + 1
        )

        top30 = bilateral_df.head(TOP_N).copy()

        # ====================================================
        # 调整列
        # ====================================================

        top30 = top30[
            [
                "rank",
                "partner_code",
                "partner_name",
                "china_export",
                "china_import",
                "china_trade_total",
            ]
        ]

        # ====================================================
        # 中文列名
        # ====================================================

        top30 = top30.rename(columns={

            "rank":
                "rank_排名",

            "partner_code":
                "partner_code_伙伴国代码",

            "partner_name":
                "partner_name_伙伴国名称",

            "china_export":
                "china_export_中国出口额",

            "china_import":
                "china_import_中国进口额",

            "china_trade_total":
                "china_trade_total_中国双边贸易总额",
        })

        # ====================================================
        # 保存
        # ====================================================

        print("\n保存 CSV...")

        top30.to_csv(
            OUTPUT_FILE,
            index=False,
            encoding="utf-8-sig",
            float_format="%.2f"
        )

        # ====================================================
        # 输出
        # ====================================================

        elapsed = time.time() - start_time

        print("\n" + "=" * 72)
        print("运行完成")
        print("=" * 72)

        print(f"\n输出文件：")
        print(OUTPUT_FILE)

        print(f"\n总耗时：{elapsed:.2f} 秒")

        print("\nTop30：")
        print(
            top30.to_string(index=False)
        )


if __name__ == "__main__":
    main()
