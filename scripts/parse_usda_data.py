#!/usr/bin/env python3
"""
USDA FNDDS (Food and Nutrient Database for Dietary Studies) Parser
将 SAS7BDAT 格式的 USDA 数据文件转换为 SQLite 数据库

依赖:
    pip install pandas pyreadstat sqlite3
"""

import os
import sys
import sqlite3
import pandas as pd
import pyreadstat
from pathlib import Path


class USDADataParser:
    """解析 USDA FNDDS 数据并创建 SQLite 数据库"""
    
    def __init__(self, data_dir: str, output_db: str):
        self.data_dir = Path(data_dir)
        self.output_db = output_db
        self.conn = None
        
        # USDA FNDDS 文件映射
        self.file_mapping = {
            'main_food_desc': 'mainfooddesc.sas7bdat',      # 主要食物描述
            'add_food_desc': 'addfooddesc.sas7bdat',        # 额外食物描述
            'food_portion_desc': 'foodportiondesc.sas7bdat', # 食物份量描述
            'food_weights': 'foodweights.sas7bdat',         # 食物重量
            'fndds_nut_val': 'fnddsnutval.sas7bdat',       # 食物营养值
            'nut_desc': 'nutdesc.sas7bdat',                 # 营养素描述
            'fndds_ingred': 'fnddsingred.sas7bdat',        # 食物成分
            'ingred_nut_val': 'ingrednutval.sas7bdat',     # 成分营养值
            'deriv_desc': 'derivdesc.sas7bdat',            # 派生描述
            'moist_adjust': 'moistadjust.sas7bdat',        # 水分调整
        }
    
    def connect_db(self):
        """创建数据库连接"""
        self.conn = sqlite3.connect(self.output_db)
        print(f"✓ 已连接到数据库: {self.output_db}")
    
    def read_sas_file(self, filename: str) -> pd.DataFrame:
        """读取 SAS7BDAT 文件"""
        filepath = self.data_dir / filename
        if not filepath.exists():
            print(f"⚠ 文件不存在: {filepath}")
            return None
        
        try:
            df, meta = pyreadstat.read_sas7bdat(str(filepath))
            print(f"✓ 读取文件: {filename} ({len(df)} 行, {len(df.columns)} 列)")
            return df
        except Exception as e:
            print(f"✗ 读取文件失败 {filename}: {e}")
            return None
    
    def create_schema(self):
        """创建数据库表结构"""
        cursor = self.conn.cursor()
        
        # 1. 食物表 (foods) - 主要食物信息
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS foods (
            food_code INTEGER PRIMARY KEY,
            main_food_description TEXT NOT NULL,
            additional_food_description TEXT,
            cgn INTEGER,
            cg_subgroup INTEGER,
            wweia_category_number INTEGER,
            wweia_category_description TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        
        # 2. 营养素描述表 (nutrients)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS nutrients (
            nutrient_code INTEGER PRIMARY KEY,
            nutrient_description TEXT NOT NULL,
            tagname TEXT,
            unit TEXT,
            nutrient_decimal_places INTEGER
        )
        """)
        
        # 3. 食物营养值表 (food_nutrients) - 每100克的营养值
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS food_nutrients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_code INTEGER NOT NULL,
            nutrient_code INTEGER NOT NULL,
            nutrient_value REAL,
            FOREIGN KEY (food_code) REFERENCES foods(food_code),
            FOREIGN KEY (nutrient_code) REFERENCES nutrients(nutrient_code),
            UNIQUE(food_code, nutrient_code)
        )
        """)
        
        # 4. 食物份量表 (food_portions)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS food_portions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_code INTEGER NOT NULL,
            seq_num INTEGER,
            portion_code TEXT,
            portion_description TEXT,
            gram_weight REAL,
            data_points INTEGER,
            standard_deviation REAL,
            FOREIGN KEY (food_code) REFERENCES foods(food_code)
        )
        """)
        
        # 5. 食物成分表 (food_ingredients)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS food_ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_code INTEGER NOT NULL,
            seq_num INTEGER,
            ingredient_code INTEGER,
            ingredient_description TEXT,
            ingredient_weight REAL,
            FOREIGN KEY (food_code) REFERENCES foods(food_code)
        )
        """)
        
        self.conn.commit()
        print("✓ 数据库表结构创建完成")
    
    def import_food_descriptions(self):
        """导入食物描述数据"""
        # 读取主要食物描述
        main_df = self.read_sas_file(self.file_mapping['main_food_desc'])
        add_df = self.read_sas_file(self.file_mapping['add_food_desc'])
        
        if main_df is None:
            print("✗ 无法读取主要食物描述文件")
            return
        
        # 合并主要描述和额外描述
        if add_df is not None:
            # 标准化列名（转换为小写）
            main_df.columns = main_df.columns.str.lower()
            add_df.columns = add_df.columns.str.lower()
            
            # 合并数据
            foods_df = main_df.merge(
                add_df, 
                on='food_code', 
                how='left',
                suffixes=('', '_add')
            )
        else:
            main_df.columns = main_df.columns.str.lower()
            foods_df = main_df
        
        # 准备数据
        foods_data = []
        for _, row in foods_df.iterrows():
            foods_data.append((
                int(row.get('food_code', 0)),
                str(row.get('main_food_description', '')),
                str(row.get('additional_food_description', '')) if 'additional_food_description' in row else None,
                int(row.get('cgn', 0)) if 'cgn' in row else None,
                int(row.get('cg_subgroup', 0)) if 'cg_subgroup' in row else None,
                int(row.get('wweia_category_number', 0)) if 'wweia_category_number' in row else None,
                str(row.get('wweia_category_description', '')) if 'wweia_category_description' in row else None,
            ))
        
        # 插入数据
        cursor = self.conn.cursor()
        cursor.executemany("""
            INSERT OR REPLACE INTO foods 
            (food_code, main_food_description, additional_food_description, 
             cgn, cg_subgroup, wweia_category_number, wweia_category_description)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, foods_data)
        
        self.conn.commit()
        print(f"✓ 导入 {len(foods_data)} 条食物描述")
    
    def import_nutrients(self):
        """导入营养素描述数据"""
        nut_desc_df = self.read_sas_file(self.file_mapping['nut_desc'])
        
        if nut_desc_df is None:
            print("✗ 无法读取营养素描述文件")
            return
        
        nut_desc_df.columns = nut_desc_df.columns.str.lower()
        
        nutrients_data = []
        for _, row in nut_desc_df.iterrows():
            nutrients_data.append((
                int(row.get('nutrient_code', 0)),
                str(row.get('nutrient_description', '')),
                str(row.get('tagname', '')) if 'tagname' in row else None,
                str(row.get('unit', '')) if 'unit' in row else None,
                int(row.get('nutrient_decimal_places', 2)) if 'nutrient_decimal_places' in row else 2,
            ))
        
        cursor = self.conn.cursor()
        cursor.executemany("""
            INSERT OR REPLACE INTO nutrients 
            (nutrient_code, nutrient_description, tagname, unit, nutrient_decimal_places)
            VALUES (?, ?, ?, ?, ?)
        """, nutrients_data)
        
        self.conn.commit()
        print(f"✓ 导入 {len(nutrients_data)} 条营养素描述")
    
    def import_food_nutrients(self):
        """导入食物营养值数据"""
        nut_val_df = self.read_sas_file(self.file_mapping['fndds_nut_val'])
        
        if nut_val_df is None:
            print("✗ 无法读取食物营养值文件")
            return
        
        nut_val_df.columns = nut_val_df.columns.str.lower()
        
        nutrients_data = []
        for _, row in nut_val_df.iterrows():
            nutrients_data.append((
                int(row.get('food_code', 0)),
                int(row.get('nutrient_code', 0)),
                float(row.get('nutrient_value', 0.0)) if pd.notna(row.get('nutrient_value')) else 0.0,
            ))
        
        cursor = self.conn.cursor()
        # 使用批量插入提高性能
        batch_size = 1000
        for i in range(0, len(nutrients_data), batch_size):
            batch = nutrients_data[i:i+batch_size]
            cursor.executemany("""
                INSERT OR REPLACE INTO food_nutrients 
                (food_code, nutrient_code, nutrient_value)
                VALUES (?, ?, ?)
            """, batch)
            if (i + batch_size) % 10000 == 0:
                print(f"  已处理 {i + batch_size} 条营养值记录...")
        
        self.conn.commit()
        print(f"✓ 导入 {len(nutrients_data)} 条食物营养值")
    
    def import_food_portions(self):
        """导入食物份量数据"""
        portion_desc_df = self.read_sas_file(self.file_mapping['food_portion_desc'])
        weights_df = self.read_sas_file(self.file_mapping['food_weights'])
        
        if weights_df is None:
            print("⚠ 无法读取食物重量文件")
            return
        
        weights_df.columns = weights_df.columns.str.lower()
        
        # foodweights 文件包含了 food_code, seq_num, portion_code, portion_weight
        # foodportiondesc 文件包含了 portion_code, portion_description
        # 我们需要合并它们
        
        portions_data = []
        
        if portion_desc_df is not None:
            portion_desc_df.columns = portion_desc_df.columns.str.lower()
            
            # 合并重量数据和描述数据
            portions_df = weights_df.merge(
                portion_desc_df[['portion_code', 'portion_description']],
                on='portion_code',
                how='left'
            )
            
            for _, row in portions_df.iterrows():
                portions_data.append((
                    int(row.get('food_code', 0)),
                    int(row.get('seq_num', 0)),
                    str(int(row.get('portion_code', 0))) if pd.notna(row.get('portion_code')) else None,
                    str(row.get('portion_description', 'Unknown')) if pd.notna(row.get('portion_description')) else 'Unknown',
                    float(row.get('portion_weight', 0.0)) if pd.notna(row.get('portion_weight')) else 0.0,
                    None,  # data_points - 这个文件中没有
                    None,  # standard_deviation - 这个文件中没有
                ))
        else:
            # 如果没有描述文件，只使用重量数据
            for _, row in weights_df.iterrows():
                portions_data.append((
                    int(row.get('food_code', 0)),
                    int(row.get('seq_num', 0)),
                    str(int(row.get('portion_code', 0))) if pd.notna(row.get('portion_code')) else None,
                    'Unknown',
                    float(row.get('portion_weight', 0.0)) if pd.notna(row.get('portion_weight')) else 0.0,
                    None,
                    None,
                ))
        
        cursor = self.conn.cursor()
        cursor.executemany("""
            INSERT OR REPLACE INTO food_portions 
            (food_code, seq_num, portion_code, portion_description, 
             gram_weight, data_points, standard_deviation)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, portions_data)
        
        self.conn.commit()
        print(f"✓ 导入 {len(portions_data)} 条食物份量")
    
    def import_food_ingredients(self):
        """导入食物成分数据"""
        ingred_df = self.read_sas_file(self.file_mapping['fndds_ingred'])
        
        if ingred_df is None:
            print("⚠ 无法读取食物成分文件")
            return
        
        ingred_df.columns = ingred_df.columns.str.lower()
        
        ingredients_data = []
        for _, row in ingred_df.iterrows():
            ingredients_data.append((
                int(row.get('food_code', 0)),
                int(row.get('seq_num', 0)),
                int(row.get('ingredient_code', 0)),
                str(row.get('ingredient_description', '')),
                float(row.get('ingredient_weight', 0.0)) if pd.notna(row.get('ingredient_weight')) else 0.0,
            ))
        
        cursor = self.conn.cursor()
        cursor.executemany("""
            INSERT OR REPLACE INTO food_ingredients 
            (food_code, seq_num, ingredient_code, ingredient_description, ingredient_weight)
            VALUES (?, ?, ?, ?, ?)
        """, ingredients_data)
        
        self.conn.commit()
        print(f"✓ 导入 {len(ingredients_data)} 条食物成分")
    
    def create_indexes(self):
        """创建索引以优化查询性能"""
        cursor = self.conn.cursor()
        
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_foods_description ON foods(main_food_description)",
            "CREATE INDEX IF NOT EXISTS idx_food_nutrients_food ON food_nutrients(food_code)",
            "CREATE INDEX IF NOT EXISTS idx_food_nutrients_nutrient ON food_nutrients(nutrient_code)",
            "CREATE INDEX IF NOT EXISTS idx_food_portions_food ON food_portions(food_code)",
            "CREATE INDEX IF NOT EXISTS idx_food_ingredients_food ON food_ingredients(food_code)",
        ]
        
        for idx_sql in indexes:
            cursor.execute(idx_sql)
        
        self.conn.commit()
        print("✓ 创建索引完成")
    
    def print_statistics(self):
        """打印数据库统计信息"""
        cursor = self.conn.cursor()
        
        print("\n" + "="*50)
        print("数据库统计信息:")
        print("="*50)
        
        tables = ['foods', 'nutrients', 'food_nutrients', 'food_portions', 'food_ingredients']
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            count = cursor.fetchone()[0]
            print(f"  {table:20s}: {count:,} 条记录")
        
        print("="*50)
    
    def run(self):
        """执行完整的数据导入流程"""
        print("\n开始解析 USDA FNDDS 数据...")
        print("="*50)
        
        try:
            self.connect_db()
            self.create_schema()
            
            print("\n第1步: 导入食物描述...")
            self.import_food_descriptions()
            
            print("\n第2步: 导入营养素描述...")
            self.import_nutrients()
            
            print("\n第3步: 导入食物营养值...")
            self.import_food_nutrients()
            
            print("\n第4步: 导入食物份量...")
            self.import_food_portions()
            
            print("\n第5步: 导入食物成分...")
            self.import_food_ingredients()
            
            print("\n第6步: 创建索引...")
            self.create_indexes()
            
            self.print_statistics()
            
            print("\n✓ 数据导入完成!")
            print(f"✓ 数据库文件: {self.output_db}")
            
        except Exception as e:
            print(f"\n✗ 错误: {e}")
            import traceback
            traceback.print_exc()
        finally:
            if self.conn:
                self.conn.close()


def main():
    """主函数"""
    # 设置路径
    base_dir = Path(__file__).parent.parent
    data_dir = base_dir / "fooddata"
    output_db = base_dir / "assets" / "usda_foods.db"
    
    # 确保 assets 目录存在
    output_db.parent.mkdir(parents=True, exist_ok=True)
    
    # 运行解析器
    parser = USDADataParser(str(data_dir), str(output_db))
    parser.run()


if __name__ == "__main__":
    main()
