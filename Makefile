# KetoPilot 数据库管理命令

.PHONY: help setup parse verify query inspect clean

help:
	@echo "KetoPilot 数据库管理命令:"
	@echo ""
	@echo "  make setup    - 创建 conda 环境并安装依赖"
	@echo "  make parse    - 解析 USDA 数据并生成 SQLite 数据库"
	@echo "  make verify   - 验证数据库完整性"
	@echo "  make query    - 运行查询示例"
	@echo "  make inspect  - 检查原始数据文件结构"
	@echo "  make clean    - 删除生成的数据库文件"
	@echo ""

setup:
	@echo "创建 conda 环境..."
	conda env create -f environment.yml || conda env update -f environment.yml
	@echo "✓ 环境设置完成！使用 'conda activate ketopilot' 激活环境"

parse:
	@echo "解析 USDA 数据..."
	conda run -n ketopilot python scripts/parse_usda_data.py

verify:
	@echo "验证数据库..."
	conda run -n ketopilot python scripts/verify_database.py

query:
	@echo "运行查询示例..."
	conda run -n ketopilot python scripts/query_examples.py

inspect:
	@echo "检查数据文件..."
	conda run -n ketopilot python scripts/inspect_data.py

clean:
	@echo "删除生成的数据库..."
	rm -f assets/usda_foods.db
	@echo "✓ 清理完成"

# 快捷方式：一次性完成解析和验证
all: parse verify
	@echo ""
	@echo "✓ 数据库生成并验证完成！"
	@echo "数据库位置: assets/usda_foods.db"
