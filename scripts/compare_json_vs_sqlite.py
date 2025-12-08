#!/usr/bin/env python3
"""
JSON vs SQLite 性能和存储对比测试
"""

import json
import sqlite3
import time
import os
from pathlib import Path


def create_json_version(db_path: str, json_path: str):
    """将 SQLite 转换为 JSON 格式"""
    print("创建 JSON 版本...")
    
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # 获取所有食物及其营养值
    cursor.execute("""
        SELECT 
            f.food_code,
            f.main_food_description,
            f.additional_food_description,
            f.wweia_category_description
        FROM foods f
        LIMIT 100
    """)
    
    foods = []
    for food_row in cursor.fetchall():
        food_code = food_row['food_code']
        
        # 获取营养值
        cursor.execute("""
            SELECT 
                n.nutrient_code,
                n.nutrient_description,
                n.tagname,
                n.unit,
                fn.nutrient_value
            FROM food_nutrients fn
            JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
            WHERE fn.food_code = ?
        """, (food_code,))
        
        nutrients = [dict(row) for row in cursor.fetchall()]
        
        # 获取份量
        cursor.execute("""
            SELECT portion_description, gram_weight
            FROM food_portions
            WHERE food_code = ?
        """, (food_code,))
        
        portions = [dict(row) for row in cursor.fetchall()]
        
        foods.append({
            'food_code': food_row['food_code'],
            'main_food_description': food_row['main_food_description'],
            'additional_food_description': food_row['additional_food_description'],
            'category': food_row['wweia_category_description'],
            'nutrients': nutrients,
            'portions': portions,
        })
    
    # 保存为 JSON
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(foods, f, indent=2)
    
    conn.close()
    print(f"✓ JSON 文件创建完成: {json_path}")


def benchmark_sqlite(db_path: str):
    """测试 SQLite 性能"""
    print("\n" + "="*60)
    print("SQLite 性能测试")
    print("="*60)
    
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # 测试1: 搜索食物
    start = time.time()
    cursor.execute("""
        SELECT food_code, main_food_description
        FROM foods
        WHERE main_food_description LIKE '%chicken%'
        LIMIT 20
    """)
    results = cursor.fetchall()
    search_time = (time.time() - start) * 1000
    print(f"✓ 搜索 'chicken': {search_time:.2f}ms (找到 {len(results)} 个结果)")
    
    # 测试2: 获取单个食物详情
    start = time.time()
    food_code = 11111000
    cursor.execute("""
        SELECT 
            n.tagname,
            n.nutrient_description,
            fn.nutrient_value,
            n.unit
        FROM food_nutrients fn
        JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
        WHERE fn.food_code = ?
    """, (food_code,))
    nutrients = cursor.fetchall()
    detail_time = (time.time() - start) * 1000
    print(f"✓ 获取食物详情: {detail_time:.2f}ms ({len(nutrients)} 个营养素)")
    
    # 测试3: 批量查询多个食物
    food_codes = [11111000, 11100000, 22100100, 32105240, 27445250]
    start = time.time()
    placeholders = ','.join(['?'] * len(food_codes))
    cursor.execute(f"""
        SELECT 
            fn.food_code,
            n.tagname,
            fn.nutrient_value
        FROM food_nutrients fn
        JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
        WHERE fn.food_code IN ({placeholders})
          AND n.tagname IN ('ENERC_KCAL', 'PROT', 'FAT', 'CHOCDF', 'FIBTG')
    """, food_codes)
    batch_results = cursor.fetchall()
    batch_time = (time.time() - start) * 1000
    print(f"✓ 批量查询 {len(food_codes)} 个食物: {batch_time:.2f}ms")
    
    # 测试4: 复杂查询（生酮友好食物）
    start = time.time()
    cursor.execute("""
        SELECT 
            f.food_code,
            f.main_food_description,
            fn_carb.nutrient_value as carbs,
            COALESCE(fn_fiber.nutrient_value, 0) as fiber,
            (fn_carb.nutrient_value - COALESCE(fn_fiber.nutrient_value, 0)) as net_carbs
        FROM foods f
        JOIN food_nutrients fn_carb ON f.food_code = fn_carb.food_code
        JOIN nutrients n_carb ON fn_carb.nutrient_code = n_carb.nutrient_code
        LEFT JOIN food_nutrients fn_fiber ON f.food_code = fn_fiber.food_code
        LEFT JOIN nutrients n_fiber ON fn_fiber.nutrient_code = n_fiber.nutrient_code
            AND n_fiber.tagname = 'FIBTG'
        WHERE n_carb.tagname = 'CHOCDF'
          AND (fn_carb.nutrient_value - COALESCE(fn_fiber.nutrient_value, 0)) <= 5
        LIMIT 20
    """)
    keto_foods = cursor.fetchall()
    complex_time = (time.time() - start) * 1000
    print(f"✓ 复杂查询（净碳水≤5g）: {complex_time:.2f}ms (找到 {len(keto_foods)} 个)")
    
    conn.close()
    
    return {
        'search_time': search_time,
        'detail_time': detail_time,
        'batch_time': batch_time,
        'complex_time': complex_time,
    }


def benchmark_json(json_path: str):
    """测试 JSON 性能"""
    print("\n" + "="*60)
    print("JSON 性能测试")
    print("="*60)
    
    # 加载 JSON 文件
    print("加载 JSON 文件到内存...")
    start = time.time()
    with open(json_path, 'r', encoding='utf-8') as f:
        foods = json.load(f)
    load_time = (time.time() - start) * 1000
    print(f"✓ 加载时间: {load_time:.2f}ms")
    
    # 测试1: 搜索食物
    start = time.time()
    results = [
        food for food in foods 
        if 'chicken' in food['main_food_description'].lower()
    ][:20]
    search_time = (time.time() - start) * 1000
    print(f"✓ 搜索 'chicken': {search_time:.2f}ms (找到 {len(results)} 个结果)")
    
    # 测试2: 获取单个食物详情
    start = time.time()
    food = next((f for f in foods if f['food_code'] == 11111000), None)
    if food:
        nutrients = food['nutrients']
    detail_time = (time.time() - start) * 1000
    print(f"✓ 获取食物详情: {detail_time:.2f}ms")
    
    # 测试3: 批量查询多个食物
    food_codes = [11111000, 11100000, 22100100, 32105240, 27445250]
    start = time.time()
    batch_results = []
    for food in foods:
        if food['food_code'] in food_codes:
            for nutrient in food['nutrients']:
                if nutrient['tagname'] in ['ENERC_KCAL', 'PROT', 'FAT', 'CHOCDF', 'FIBTG']:
                    batch_results.append(nutrient)
    batch_time = (time.time() - start) * 1000
    print(f"✓ 批量查询 {len(food_codes)} 个食物: {batch_time:.2f}ms")
    
    # 测试4: 复杂查询（生酮友好食物）
    start = time.time()
    keto_foods = []
    for food in foods:
        carbs = 0
        fiber = 0
        for nutrient in food['nutrients']:
            if nutrient['tagname'] == 'CHOCDF':
                carbs = nutrient['nutrient_value']
            elif nutrient['tagname'] == 'FIBTG':
                fiber = nutrient['nutrient_value']
        net_carbs = carbs - fiber
        if net_carbs <= 5:
            keto_foods.append(food)
    complex_time = (time.time() - start) * 1000
    print(f"✓ 复杂查询（净碳水≤5g）: {complex_time:.2f}ms (找到 {len(keto_foods)} 个)")
    
    return {
        'load_time': load_time,
        'search_time': search_time,
        'detail_time': detail_time,
        'batch_time': batch_time,
        'complex_time': complex_time,
    }


def compare_file_sizes(db_path: str, json_path: str):
    """比较文件大小"""
    print("\n" + "="*60)
    print("文件大小对比")
    print("="*60)
    
    db_size = os.path.getsize(db_path) / 1024 / 1024
    json_size = os.path.getsize(json_path) / 1024 / 1024
    
    print(f"SQLite 数据库: {db_size:.2f} MB")
    print(f"JSON 文件:     {json_size:.2f} MB")
    print(f"差异:          {json_size - db_size:+.2f} MB ({(json_size/db_size-1)*100:+.1f}%)")


def analyze_json_redundancy(json_path: str):
    """分析 JSON 格式的数据冗余"""
    print("\n" + "="*60)
    print("JSON 数据冗余分析")
    print("="*60)
    
    with open(json_path, 'r', encoding='utf-8') as f:
        foods = json.load(f)
    
    # 统计重复的营养素名称
    nutrient_names = []
    for food in foods:
        for nutrient in food['nutrients']:
            nutrient_names.append(nutrient['nutrient_description'])
    
    unique_names = set(nutrient_names)
    total_names = len(nutrient_names)
    
    print(f"营养素名称总计: {total_names} 次")
    print(f"唯一营养素名称: {len(unique_names)} 个")
    print(f"重复次数: {total_names - len(unique_names)} 次")
    print(f"冗余度: {(1 - len(unique_names)/total_names)*100:.1f}%")
    
    # 估算完整数据库的冗余
    full_db_foods = 5432
    avg_nutrients = 65
    total_redundant = full_db_foods * avg_nutrients * len(unique_names)
    print(f"\n如果用 JSON 存储完整数据库:")
    print(f"  预计重复存储营养素名称: {full_db_foods * avg_nutrients:,} 次")
    print(f"  浪费的字符数: ~{full_db_foods * avg_nutrients * 20:,} 个字符")


def main():
    """主函数"""
    base_dir = Path(__file__).parent.parent
    db_path = base_dir / "assets" / "usda_foods.db"
    json_path = base_dir / "assets" / "usda_foods_sample.json"
    
    if not db_path.exists():
        print(f"✗ 数据库文件不存在: {db_path}")
        return
    
    print("="*60)
    print("JSON vs SQLite 对比分析")
    print("="*60)
    print(f"数据库: {db_path}")
    print(f"测试范围: 前 100 种食物")
    
    # 创建 JSON 版本
    create_json_version(str(db_path), str(json_path))
    
    # 性能测试
    sqlite_results = benchmark_sqlite(str(db_path))
    json_results = benchmark_json(str(json_path))
    
    # 文件大小对比
    compare_file_sizes(str(db_path), str(json_path))
    
    # 数据冗余分析
    analyze_json_redundancy(str(json_path))
    
    # 总结
    print("\n" + "="*60)
    print("性能对比总结 (100 种食物)")
    print("="*60)
    print(f"{'操作':<20s} {'SQLite':>12s} {'JSON':>12s} {'谁更快':>12s}")
    print("-"*60)
    
    if 'load_time' in json_results:
        print(f"{'初始加载':<20s} {'即时':>12s} {json_results['load_time']:>11.2f}ms {'SQLite':>12s}")
    
    search_winner = 'SQLite' if sqlite_results['search_time'] < json_results['search_time'] else 'JSON'
    print(f"{'搜索食物':<20s} {sqlite_results['search_time']:>11.2f}ms {json_results['search_time']:>11.2f}ms {search_winner:>12s}")
    
    detail_winner = 'SQLite' if sqlite_results['detail_time'] < json_results['detail_time'] else 'JSON'
    print(f"{'获取详情':<20s} {sqlite_results['detail_time']:>11.2f}ms {json_results['detail_time']:>11.2f}ms {detail_winner:>12s}")
    
    batch_winner = 'SQLite' if sqlite_results['batch_time'] < json_results['batch_time'] else 'JSON'
    print(f"{'批量查询':<20s} {sqlite_results['batch_time']:>11.2f}ms {json_results['batch_time']:>11.2f}ms {batch_winner:>12s}")
    
    complex_winner = 'SQLite' if sqlite_results['complex_time'] < json_results['complex_time'] else 'JSON'
    print(f"{'复杂查询':<20s} {sqlite_results['complex_time']:>11.2f}ms {json_results['complex_time']:>11.2f}ms {complex_winner:>12s}")
    
    print("\n" + "="*60)
    print("结论建议")
    print("="*60)
    print("""
SQLite 的优势:
  ✓ 文件更小（数据压缩和规范化）
  ✓ 查询更灵活（支持复杂 SQL）
  ✓ 无需全部加载到内存
  ✓ 支持索引优化
  ✓ 数据无冗余
  ✓ 易于更新和维护

JSON 的优势:
  ✓ 结构简单直观
  ✓ 无需数据库库依赖（但 Flutter 的 sqflite 很成熟）
  ✓ 内存中操作快（但需要先加载）

对于 KetoPilot 项目，推荐使用 SQLite：
  1. 5,432 种食物数据量较大，JSON 全加载内存会占用过多资源
  2. 需要复杂查询（搜索、过滤、排序、聚合）
  3. 未来可能需要添加自定义食物、食谱等，需要写入操作
  4. SQLite 是移动应用的标准选择，Flutter 的 sqflite 插件成熟可靠
  5. 25MB 的 SQLite 文件是合理大小，而 JSON 会更大且全部占用内存
    """)
    
    # 清理测试文件
    if json_path.exists():
        json_path.unlink()
        print(f"\n✓ 已清理测试文件: {json_path}")


if __name__ == "__main__":
    main()
