# USDA 食物数据库集成指南

## 完成情况

✅ **数据解析完成**
- 已成功将 USDA FNDDS SAS 数据文件转换为 SQLite 数据库
- 数据库文件: `assets/usda_foods.db` (25 MB)
- 包含 5,432 种食物，353,015 条营养值记录

## 数据库内容

### 统计信息
- **食物数量**: 5,432 种
- **营养素种类**: 65 种
- **营养值记录**: 353,015 条
- **份量选项**: 22,046 条
- **食物成分**: 18,584 条

### 数据库表结构

#### 1. `foods` - 食物表
| 字段 | 类型 | 说明 |
|------|------|------|
| food_code | INTEGER | 食物代码（主键）|
| main_food_description | TEXT | 食物名称 |
| additional_food_description | TEXT | 额外描述 |
| wweia_category_description | TEXT | 食物分类 |

#### 2. `nutrients` - 营养素表
| 字段 | 类型 | 说明 |
|------|------|------|
| nutrient_code | INTEGER | 营养素代码（主键）|
| nutrient_description | TEXT | 营养素名称 |
| tagname | TEXT | 标签（如 ENERC_KCAL, PROT）|
| unit | TEXT | 单位（g, mg, kcal）|

#### 3. `food_nutrients` - 食物营养值表（每100克）
| 字段 | 类型 | 说明 |
|------|------|------|
| food_code | INTEGER | 食物代码 |
| nutrient_code | INTEGER | 营养素代码 |
| nutrient_value | REAL | 营养值 |

#### 4. `food_portions` - 食物份量表
| 字段 | 类型 | 说明 |
|------|------|------|
| food_code | INTEGER | 食物代码 |
| portion_description | TEXT | 份量描述（如 "1 cup"）|
| gram_weight | REAL | 对应克重 |

## Flutter 集成步骤

### 步骤 1: 添加依赖
在 `pubspec.yaml` 中添加：
```yaml
dependencies:
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  path: ^1.8.3
```

### 步骤 2: 配置资源文件
在 `pubspec.yaml` 中添加：
```yaml
flutter:
  assets:
    - assets/usda_foods.db
```

### 步骤 3: 创建数据库服务
创建文件 `lib/core/services/food_database_service.dart`

参考 `scripts/query_examples.py` 中的查询逻辑实现以下功能：
- `searchFoods(String query)` - 搜索食物
- `getFoodDetails(int foodCode)` - 获取食物详情
- `getMacrosForPortion(int foodCode, double grams)` - 计算营养值

### 步骤 4: 创建 UI 组件
- 食物搜索界面
- 食物详情展示
- 份量选择器
- 营养值计算器

## 重要营养素标签（tagname）

### 生酮饮食关注的营养素
- `ENERC_KCAL` - 能量（千卡）
- `PROT` - 蛋白质（g）
- `FAT` - 总脂肪（g）
- `CHOCDF` - 碳水化合物（g）
- `FIBTG` - 膳食纤维（g）
- `SUGAR` - 糖（g）

**净碳水计算**: `净碳水 = 碳水化合物 - 膳食纤维`

### 其他重要营养素
- `NA` - 钠（mg）
- `CA` - 钙（mg）
- `FE` - 铁（mg）
- `VITA_RAE` - 维生素A（μg）
- `VITC` - 维生素C（mg）
- `VITD` - 维生素D（μg）

## 查询示例

### 搜索食物
```sql
SELECT food_code, main_food_description 
FROM foods 
WHERE main_food_description LIKE '%chicken%'
LIMIT 20;
```

### 获取食物营养值（每100克）
```sql
SELECT 
    n.tagname,
    n.nutrient_description,
    fn.nutrient_value,
    n.unit
FROM food_nutrients fn
JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
WHERE fn.food_code = 11111000
  AND n.tagname IN ('ENERC_KCAL', 'PROT', 'FAT', 'CHOCDF', 'FIBTG');
```

### 计算指定克数的营养值
```sql
SELECT 
    n.tagname,
    ROUND(fn.nutrient_value * 150 / 100, 2) as value,
    n.unit
FROM food_nutrients fn
JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
WHERE fn.food_code = 11111000;
```

### 获取食物份量选项
```sql
SELECT 
    portion_description,
    gram_weight
FROM food_portions
WHERE food_code = 11111000;
```

## 使用 Python 脚本

### 环境设置
```bash
# 激活 conda 环境
conda activate ketopilot

# 安装依赖（如果还没安装）
pip install pandas pyreadstat
```

### 重新生成数据库
```bash
python scripts/parse_usda_data.py
```

### 验证数据库
```bash
python scripts/verify_database.py
```

### 查看查询示例
```bash
python scripts/query_examples.py
```

### 检查数据文件结构
```bash
python scripts/inspect_data.py
```

## 性能优化

数据库已包含以下索引：
- `idx_foods_description` - 快速搜索食物名称
- `idx_food_nutrients_food` - 快速查询食物营养
- `idx_food_nutrients_nutrient` - 按营养素查询
- `idx_food_portions_food` - 快速查询份量选项

## 下一步工作

1. ✅ 数据解析和导入（已完成）
2. ⏳ 实现 Flutter 数据库服务层
3. ⏳ 创建食物搜索 UI
4. ⏳ 实现营养值计算功能
5. ⏳ 集成到食物日记功能
6. ⏳ 添加自定义食物功能
7. ⏳ 实现每日营养目标追踪

## 文件清单

### Python 脚本（`scripts/`）
- `parse_usda_data.py` - 主数据解析脚本
- `verify_database.py` - 数据库验证脚本
- `query_examples.py` - 查询示例脚本
- `inspect_data.py` - 数据文件检查脚本
- `requirements.txt` - Python 依赖
- `README.md` - 脚本文档

### 数据文件
- `fooddata/*.sas7bdat` - 原始 USDA 数据文件（10个）
- `assets/usda_foods.db` - 生成的 SQLite 数据库（25 MB）

## 技术栈

- **数据格式**: SAS7BDAT → SQLite
- **Python 库**: pandas, pyreadstat
- **数据库**: SQLite 3
- **Flutter 集成**: sqflite
- **数据量**: 5,432 种食物，353,015 条营养记录

## 许可和引用

数据来源: USDA Food and Nutrient Database for Dietary Studies (FNDDS)
- 网站: https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/food-surveys-research-group/docs/fndds/
- 许可: Public Domain (美国政府数据)

## 联系和支持

如有问题，请查看：
1. `scripts/README.md` - 详细的脚本文档
2. `scripts/query_examples.py` - 查询示例代码
3. `scripts/verify_database.py` - 数据验证示例
