#!/usr/bin/env python3
"""
数据库查询示例
演示如何在应用中查询和使用 USDA 食物数据
"""

import sqlite3
from pathlib import Path


class FoodDatabase:
    """食物数据库查询接口"""
    
    def __init__(self, db_path: str):
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row
    
    def search_foods(self, query: str, limit: int = 20):
        """搜索食物
        
        Args:
            query: 搜索关键词
            limit: 返回结果数量限制
            
        Returns:
            食物列表，每个食物包含 food_code 和 description
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT 
                food_code,
                main_food_description as description,
                wweia_category_description as category
            FROM foods
            WHERE main_food_description LIKE ?
               OR additional_food_description LIKE ?
            ORDER BY main_food_description
            LIMIT ?
        """, (f"%{query}%", f"%{query}%", limit))
        
        return [dict(row) for row in cursor.fetchall()]
    
    def get_food_details(self, food_code: int):
        """获取食物详细信息
        
        Args:
            food_code: 食物代码
            
        Returns:
            食物详情字典，包含基本信息、营养值和份量选项
        """
        cursor = self.conn.cursor()
        
        # 1. 基本信息
        cursor.execute("""
            SELECT 
                food_code,
                main_food_description as name,
                additional_food_description,
                wweia_category_description as category
            FROM foods
            WHERE food_code = ?
        """, (food_code,))
        
        food_info = dict(cursor.fetchone() or {})
        if not food_info:
            return None
        
        # 2. 营养值（每100克）
        cursor.execute("""
            SELECT 
                n.nutrient_code,
                n.tagname,
                n.nutrient_description as name,
                fn.nutrient_value as value,
                n.unit
            FROM food_nutrients fn
            JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
            WHERE fn.food_code = ?
            ORDER BY n.nutrient_code
        """, (food_code,))
        
        food_info['nutrients'] = [dict(row) for row in cursor.fetchall()]
        
        # 3. 份量选项
        cursor.execute("""
            SELECT 
                seq_num,
                portion_code,
                portion_description,
                gram_weight
            FROM food_portions
            WHERE food_code = ?
            ORDER BY seq_num
        """, (food_code,))
        
        food_info['portions'] = [dict(row) for row in cursor.fetchall()]
        
        return food_info
    
    def calculate_nutrients_for_portion(self, food_code: int, grams: float):
        """计算指定克数的营养值
        
        Args:
            food_code: 食物代码
            grams: 克数
            
        Returns:
            营养值字典
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT 
                n.tagname,
                n.nutrient_description as name,
                ROUND(fn.nutrient_value * ? / 100, 2) as value,
                n.unit
            FROM food_nutrients fn
            JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
            WHERE fn.food_code = ?
            ORDER BY n.nutrient_code
        """, (grams, food_code))
        
        return [dict(row) for row in cursor.fetchall()]
    
    def get_macros_for_portion(self, food_code: int, grams: float):
        """获取指定克数的宏量营养素（生酮饮食重点关注）
        
        Args:
            food_code: 食物代码
            grams: 克数
            
        Returns:
            包含能量、蛋白质、脂肪、碳水、纤维、净碳水的字典
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT 
                n.tagname,
                ROUND(fn.nutrient_value * ? / 100, 2) as value
            FROM food_nutrients fn
            JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
            WHERE fn.food_code = ?
              AND n.tagname IN ('ENERC_KCAL', 'PROT', 'FAT', 'CHOCDF', 'FIBTG', 'SUGAR')
        """, (grams, food_code))
        
        nutrients = {row['tagname']: row['value'] for row in cursor.fetchall()}
        
        # 计算净碳水（碳水 - 纤维）
        carbs = nutrients.get('CHOCDF', 0)
        fiber = nutrients.get('FIBTG', 0)
        net_carbs = max(0, carbs - fiber)
        
        return {
            'calories': nutrients.get('ENERC_KCAL', 0),
            'protein': nutrients.get('PROT', 0),
            'fat': nutrients.get('FAT', 0),
            'carbohydrates': carbs,
            'fiber': fiber,
            'net_carbs': net_carbs,
            'sugar': nutrients.get('SUGAR', 0),
        }
    
    def close(self):
        """关闭数据库连接"""
        self.conn.close()


def main():
    """演示查询功能"""
    base_dir = Path(__file__).parent.parent
    db_path = base_dir / "assets" / "usda_foods.db"
    
    db = FoodDatabase(str(db_path))
    
    try:
        print("="*60)
        print("USDA 食物数据库查询示例")
        print("="*60)
        
        # 示例 1: 搜索食物
        print("\n1. 搜索食物: 'egg'")
        print("-"*60)
        results = db.search_foods('egg', limit=5)
        for i, food in enumerate(results, 1):
            print(f"{i}. [{food['food_code']}] {food['description']}")
            if food['category']:
                print(f"   类别: {food['category']}")
        
        # 示例 2: 获取食物详情
        if results:
            food_code = results[0]['food_code']
            print(f"\n2. 食物详情: {results[0]['description']}")
            print("-"*60)
            
            details = db.get_food_details(food_code)
            
            print("\n重要营养成分 (每100克):")
            key_nutrients = ['ENERC_KCAL', 'PROT', 'FAT', 'CHOCDF', 'FIBTG', 'SUGAR']
            for nutrient in details['nutrients']:
                if nutrient['tagname'] in key_nutrients:
                    print(f"  {nutrient['name']:25s}: {nutrient['value']:8.2f} {nutrient['unit']}")
            
            if details['portions']:
                print("\n可用份量 (前5个):")
                for portion in details['portions'][:5]:
                    print(f"  {portion['portion_description']:35s} = {portion['gram_weight']:6.1f}g")
        
        # 示例 3: 计算份量营养值
        print("\n3. 计算份量营养值")
        print("-"*60)
        
        # 使用第一个食物，计算 150 克的营养值
        if results:
            grams = 150
            macros = db.get_macros_for_portion(food_code, grams)
            
            print(f"\n{results[0]['description']} ({grams}g) 的宏量营养素:")
            print(f"  能量:       {macros['calories']:6.1f} kcal")
            print(f"  蛋白质:     {macros['protein']:6.2f} g")
            print(f"  脂肪:       {macros['fat']:6.2f} g")
            print(f"  碳水化合物: {macros['carbohydrates']:6.2f} g")
            print(f"  膳食纤维:   {macros['fiber']:6.2f} g")
            print(f"  净碳水:     {macros['net_carbs']:6.2f} g  ← 生酮饮食关注")
            print(f"  糖:         {macros['sugar']:6.2f} g")
        
        # 示例 4: 生酮友好食物搜索
        print("\n4. 生酮友好食物示例")
        print("-"*60)
        
        keto_foods = ['avocado', 'cheese', 'bacon', 'salmon']
        for food_name in keto_foods:
            results = db.search_foods(food_name, limit=1)
            if results:
                food = results[0]
                macros = db.get_macros_for_portion(food['food_code'], 100)
                print(f"\n{food['description']} (100g):")
                print(f"  净碳水: {macros['net_carbs']:.1f}g | "
                      f"脂肪: {macros['fat']:.1f}g | "
                      f"蛋白质: {macros['protein']:.1f}g | "
                      f"能量: {macros['calories']:.0f} kcal")
        
        print("\n" + "="*60)
        print("查询示例完成")
        print("="*60)
        
    finally:
        db.close()


if __name__ == "__main__":
    main()
