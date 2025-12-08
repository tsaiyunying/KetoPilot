#!/usr/bin/env python3
"""
检查 SAS 文件的列名和结构
"""

import pyreadstat
from pathlib import Path

data_dir = Path(__file__).parent.parent / "fooddata"

files = [
    'mainfooddesc.sas7bdat',
    'addfooddesc.sas7bdat',
    'foodportiondesc.sas7bdat',
    'foodweights.sas7bdat',
    'fnddsnutval.sas7bdat',
    'nutdesc.sas7bdat',
    'fnddsingred.sas7bdat',
]

for filename in files:
    filepath = data_dir / filename
    if filepath.exists():
        print(f"\n{'='*60}")
        print(f"文件: {filename}")
        print('='*60)
        try:
            df, meta = pyreadstat.read_sas7bdat(str(filepath))
            print(f"行数: {len(df)}")
            print(f"列数: {len(df.columns)}")
            print(f"\n列名:")
            for i, col in enumerate(df.columns, 1):
                dtype = df[col].dtype
                non_null = df[col].notna().sum()
                print(f"  {i:2d}. {col:30s} ({dtype}, {non_null}/{len(df)} 非空)")
            
            # 显示前几行数据
            print(f"\n前3行数据预览:")
            print(df.head(3).to_string())
            
        except Exception as e:
            print(f"错误: {e}")
