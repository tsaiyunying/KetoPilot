#!/usr/bin/env python3
"""
验证 USDA 数据库的完整性和正确性
"""

import sqlite3
from pathlib import Path


class DatabaseVerifier:
    """验证数据库数据"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row
    
    def verify_tables(self):
        """验证表是否存在"""
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' 
            ORDER BY name
        """)
        tables = [row[0] for row in cursor.fetchall()]
        
        print("\n数据库表:")
        for table in tables:
            print(f"  ✓ {table}")
        
        expected_tables = ['foods', 'nutrients', 'food_nutrients', 'food_portions', 'food_ingredients']
        missing = set(expected_tables) - set(tables)
        if missing:
            print(f"\n⚠ 缺少表: {missing}")
        
        return len(missing) == 0
    
    def verify_indexes(self):
        """验证索引是否存在"""
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='index' 
            ORDER BY name
        """)
        indexes = [row[0] for row in cursor.fetchall()]
        
        print("\n数据库索引:")
        for idx in indexes:
            if not idx.startswith('sqlite_'):  # 跳过系统索引
                print(f"  ✓ {idx}")
    
    def sample_foods(self):
        """显示食物样本"""
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT food_code, main_food_description, wweia_category_description
            FROM foods
            ORDER BY RANDOM()
            LIMIT 5
        """)
        
        print("\n食物样本:")
        for row in cursor.fetchall():
            print(f"  [{row['food_code']}] {row['main_food_description']}")
            if row['wweia_category_description']:
                print(f"       分类: {row['wweia_category_description']}")
    
    def sample_nutrients(self):
        """显示营养素样本"""
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT nutrient_code, nutrient_description, tagname, unit
            FROM nutrients
            WHERE tagname IN ('ENERC_KCAL', 'PROT', 'FAT', 'CHOCDF', 'FIBTG', 'SUGAR')
            ORDER BY nutrient_code
        """)
        
        print("\n重要营养素:")
        for row in cursor.fetchall():
            print(f"  [{row['tagname']:12s}] {row['nutrient_description']:30s} ({row['unit']})")
    
    def test_food_with_nutrients(self):
        """测试食物营养值查询"""
        cursor = self.conn.cursor()
        
        # 找一个有营养数据的食物
        cursor.execute("""
            SELECT DISTINCT f.food_code, f.main_food_description
            FROM foods f
            JOIN food_nutrients fn ON f.food_code = fn.food_code
            LIMIT 1
        """)
        
        row = cursor.fetchone()
        if not row:
            print("\n⚠ 没有找到包含营养数据的食物")
            return
        
        food_code = row['food_code']
        food_name = row['main_food_description']
        
        print(f"\n食物详情: {food_name} (代码: {food_code})")
        print("-" * 60)
        
        # 获取营养值
        cursor.execute("""
            SELECT 
                n.tagname,
                n.nutrient_description,
                fn.nutrient_value,
                n.unit
            FROM food_nutrients fn
            JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
            WHERE fn.food_code = ?
              AND n.tagname IN ('ENERC_KCAL', 'PROT', 'FAT', 'CHOCDF', 'FIBTG', 'SUGAR', 'NA')
            ORDER BY 
                CASE n.tagname
                    WHEN 'ENERC_KCAL' THEN 1
                    WHEN 'PROT' THEN 2
                    WHEN 'FAT' THEN 3
                    WHEN 'CHOCDF' THEN 4
                    WHEN 'FIBTG' THEN 5
                    WHEN 'SUGAR' THEN 6
                    ELSE 7
                END
        """, (food_code,))
        
        print("\n营养成分 (每100克):")
        for row in cursor.fetchall():
            print(f"  {row['nutrient_description']:25s}: {row['nutrient_value']:8.2f} {row['unit']}")
        
        # 获取份量选项
        cursor.execute("""
            SELECT portion_description, gram_weight
            FROM food_portions
            WHERE food_code = ?
            LIMIT 5
        """, (food_code,))
        
        portions = cursor.fetchall()
        if portions:
            print("\n可用份量:")
            for row in portions:
                print(f"  {row['portion_description']:30s} = {row['gram_weight']:6.1f}g")
    
    def test_search(self):
        """测试搜索功能"""
        search_term = "chicken"
        print(f"\n搜索测试: '{search_term}'")
        print("-" * 60)
        
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT food_code, main_food_description
            FROM foods
            WHERE main_food_description LIKE ?
            LIMIT 5
        """, (f"%{search_term}%",))
        
        results = cursor.fetchall()
        print(f"找到 {len(results)} 个结果 (显示前5个):")
        for row in results:
            print(f"  [{row['food_code']}] {row['main_food_description']}")
    
    def calculate_net_carbs_example(self):
        """演示净碳水计算"""
        cursor = self.conn.cursor()
        
        # 找一个含有碳水和纤维的食物
        cursor.execute("""
            SELECT DISTINCT f.food_code, f.main_food_description
            FROM foods f
            JOIN food_nutrients fn1 ON f.food_code = fn1.food_code
            JOIN nutrients n1 ON fn1.nutrient_code = n1.nutrient_code
            JOIN food_nutrients fn2 ON f.food_code = fn2.food_code
            JOIN nutrients n2 ON fn2.nutrient_code = n2.nutrient_code
            WHERE n1.tagname = 'CHOCDF' AND fn1.nutrient_value > 0
              AND n2.tagname = 'FIBTG' AND fn2.nutrient_value > 0
            LIMIT 1
        """)
        
        row = cursor.fetchone()
        if not row:
            print("\n⚠ 没有找到包含碳水和纤维的食物")
            return
        
        food_code = row['food_code']
        food_name = row['main_food_description']
        
        # 获取碳水和纤维值
        cursor.execute("""
            SELECT 
                n.tagname,
                n.nutrient_description,
                fn.nutrient_value
            FROM food_nutrients fn
            JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
            WHERE fn.food_code = ?
              AND n.tagname IN ('CHOCDF', 'FIBTG')
        """, (food_code,))
        
        nutrients = {row['tagname']: row['nutrient_value'] for row in cursor.fetchall()}
        
        if 'CHOCDF' in nutrients and 'FIBTG' in nutrients:
            carbs = nutrients['CHOCDF']
            fiber = nutrients['FIBTG']
            net_carbs = carbs - fiber
            
            print(f"\n净碳水计算示例: {food_name}")
            print("-" * 60)
            print(f"  总碳水化合物: {carbs:.2f}g")
            print(f"  膳食纤维:     {fiber:.2f}g")
            print(f"  净碳水:       {net_carbs:.2f}g  (生酮饮食关注指标)")
    
    def verify_all(self):
        """运行所有验证"""
        print("="*60)
        print("USDA 数据库验证报告")
        print("="*60)
        print(f"数据库: {self.db_path}")
        
        self.verify_tables()
        self.verify_indexes()
        self.sample_foods()
        self.sample_nutrients()
        self.test_food_with_nutrients()
        self.test_search()
        self.calculate_net_carbs_example()
        
        print("\n" + "="*60)
        print("✓ 验证完成")
        print("="*60)
    
    def close(self):
        """关闭连接"""
        self.conn.close()


def main():
    base_dir = Path(__file__).parent.parent
    db_path = base_dir / "assets" / "usda_foods.db"
    
    if not db_path.exists():
        print(f"✗ 数据库文件不存在: {db_path}")
        print("请先运行 parse_usda_data.py 来创建数据库")
        return
    
    verifier = DatabaseVerifier(str(db_path))
    try:
        verifier.verify_all()
    finally:
        verifier.close()


if __name__ == "__main__":
    main()
