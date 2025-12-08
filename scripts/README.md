# USDA 数据解析脚本

## 概述
这个脚本将 USDA FNDDS (Food and Nutrient Database for Dietary Studies) 的 SAS 格式数据转换为 SQLite 数据库，供 KetoPilot Flutter 应用使用。

## 数据结构

### 输入文件 (fooddata/)
- `mainfooddesc.sas7bdat` - 主要食物描述
- `addfooddesc.sas7bdat` - 额外食物描述
- `foodportiondesc.sas7bdat` - 食物份量描述
- `foodweights.sas7bdat` - 食物重量
- `fnddsnutval.sas7bdat` - 食物营养值 (每100克)
- `nutdesc.sas7bdat` - 营养素描述
- `fnddsingred.sas7bdat` - 食物成分
- `ingrednutval.sas7bdat` - 成分营养值
- `derivdesc.sas7bdat` - 派生描述
- `moistadjust.sas7bdat` - 水分调整

### 输出数据库结构 (assets/usda_foods.db)

#### 1. foods - 食物表
- `food_code` (INTEGER, PRIMARY KEY) - 食物代码
- `main_food_description` (TEXT) - 主要描述
- `additional_food_description` (TEXT) - 额外描述
- `cgn`, `cg_subgroup` - 食物分类
- `wweia_category_number`, `wweia_category_description` - WWEIA 分类

#### 2. nutrients - 营养素表
- `nutrient_code` (INTEGER, PRIMARY KEY) - 营养素代码
- `nutrient_description` (TEXT) - 营养素名称
- `tagname` (TEXT) - 标签名 (如 ENERC_KCAL, PROT, FAT)
- `unit` (TEXT) - 单位 (g, mg, kcal 等)

#### 3. food_nutrients - 食物营养值表
- `food_code` (INTEGER) - 食物代码
- `nutrient_code` (INTEGER) - 营养素代码
- `nutrient_value` (REAL) - 营养值 (每100克)

#### 4. food_portions - 食物份量表
- `food_code` (INTEGER) - 食物代码
- `portion_description` (TEXT) - 份量描述 (如 "1 cup", "1 slice")
- `gram_weight` (REAL) - 该份量对应的克重

#### 5. food_ingredients - 食物成分表
- `food_code` (INTEGER) - 食物代码
- `ingredient_code` (INTEGER) - 成分代码
- `ingredient_description` (TEXT) - 成分描述

## 使用方法

### 1. 安装依赖
```bash
cd scripts
pip install -r requirements.txt
```

### 2. 运行解析脚本
```bash
python parse_usda_data.py
```

脚本会:
1. 读取 `fooddata/` 目录中的所有 SAS 文件
2. 创建 `assets/usda_foods.db` SQLite 数据库
3. 导入所有数据并创建索引
4. 打印统计信息

### 3. 验证数据
```bash
python verify_database.py
```

## 数据查询示例

### 搜索食物
```sql
SELECT food_code, main_food_description 
FROM foods 
WHERE main_food_description LIKE '%chicken%'
LIMIT 10;
```

### 获取食物营养信息
```sql
SELECT 
    f.main_food_description,
    n.nutrient_description,
    n.tagname,
    fn.nutrient_value,
    n.unit
FROM food_nutrients fn
JOIN foods f ON fn.food_code = f.food_code
JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
WHERE f.food_code = 11111000
ORDER BY n.nutrient_code;
```

### 获取食物份量选项
```sql
SELECT 
    f.main_food_description,
    fp.portion_description,
    fp.gram_weight
FROM food_portions fp
JOIN foods f ON fp.food_code = f.food_code
WHERE f.food_code = 11111000;
```

### 计算特定份量的营养值
```sql
-- 例如: 1 cup chicken (假设 1 cup = 140g)
SELECT 
    n.tagname,
    n.nutrient_description,
    ROUND(fn.nutrient_value * 140 / 100, 2) as portion_value,
    n.unit
FROM food_nutrients fn
JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
WHERE fn.food_code = 11111000
  AND n.tagname IN ('ENERC_KCAL', 'PROT', 'FAT', 'CHOCDF', 'FIBTG');
```

## 重要营养素代码 (tagname)

- `ENERC_KCAL` - 能量 (千卡)
- `PROT` - 蛋白质 (g)
- `FAT` - 总脂肪 (g)
- `CHOCDF` - 碳水化合物 (g)
- `FIBTG` - 膳食纤维 (g)
- `SUGAR` - 糖 (g)
- `CA` - 钙 (mg)
- `FE` - 铁 (mg)
- `NA` - 钠 (mg)
- `VITA_RAE` - 维生素A (μg)
- `VITC` - 维生素C (mg)

## 性能优化

数据库已创建以下索引:
- `foods.main_food_description` - 快速搜索食物
- `food_nutrients.food_code` - 快速查找食物营养
- `food_nutrients.nutrient_code` - 按营养素查询
- `food_portions.food_code` - 快速查找份量选项

## 故障排除

### 问题: 无法读取 SAS 文件
- 确保已安装 `pyreadstat`: `pip install pyreadstat`
- 确认 `fooddata/` 目录包含所有 `.sas7bdat` 文件

### 问题: 内存不足
- 脚本使用批量插入 (batch_size=1000) 来减少内存使用
- 可以调整 `batch_size` 参数

### 问题: 数据库文件过大
- 当前 USDA FNDDS 数据库约 50-100 MB
- Flutter 可以轻松处理这个大小
- 如需减小，可以过滤不需要的营养素或食物类别
