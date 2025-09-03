#!/bin/bash

# 开发环境设置脚本
echo "🔧 设置分布式下载集群开发环境..."

# 检查Python虚拟环境
if [ -f "/home/jimwong/.venv/bin/python" ]; then
    echo "✅ Python虚拟环境已就绪"
    /home/jimwong/.venv/bin/python --version
else
    echo "❌ Python虚拟环境未找到，正在创建..."
    python3 -m venv /home/jimwong/.venv
    source /home/jimwong/.venv/bin/activate
fi

# 安装依赖
echo "📦 安装Python依赖..."
/home/jimwong/.venv/bin/pip install -q flask requests beautifulsoup4

# 验证安装
echo "🧪 验证环境..."
/home/jimwong/.venv/bin/python -c "
import flask, requests
from bs4 import BeautifulSoup
print('✅ 所有包导入成功!')
"

# 设置IDE环境变量
export PYTHONPATH="/home/jimwong/.venv/lib/python3.12/site-packages:$PYTHONPATH"

echo ""
echo "🎉 开发环境设置完成!"
echo "💡 现在可以在VS Code中正常开发，不会有导入警告"
echo ""
echo "🚀 快速启动命令:"
echo "  ./switch-version.sh optimized  # 启动优化版本"
echo "  ./switch-version.sh status     # 查看状态"
