#!/bin/bash

# 分布式下载集群 - 版本切换脚本
# 使用方法: ./switch-version.sh [original|optimized|status]

set -e

echo "🚀 分布式下载集群 - 版本管理工具"
echo "=================================="

case "$1" in
    "original")
        echo "🔄 切换到原版本 (完整功能, 5.2GB)..."
        docker-compose down 2>/dev/null || true
        docker-compose -f docker-compose.optimized.yml down 2>/dev/null || true
        docker-compose up -d
        echo "✅ 原版本启动完成!"
        echo "📊 监控面板: http://localhost:3000 (Grafana)"
        echo "🌐 管理界面: http://localhost:8000 (Resolver)"
        echo "🔧 爬虫服务: http://localhost:8500 (Scraper)"
        ;;
    
    "hub")
        echo "🔄 切换到Docker Hub版本 (从云端拉取, 212MB)..."
        docker-compose down 2>/dev/null || true
        docker-compose -f docker-compose.optimized.yml down 2>/dev/null || true
        docker-compose -f docker-compose.hub.yml down 2>/dev/null || true
        docker-compose -f docker-compose.hub.yml pull
        docker-compose -f docker-compose.hub.yml up -d
        echo "✅ Docker Hub版本启动完成!"
        echo "📊 监控面板: http://localhost:3001 (Grafana)"
        echo "🌐 管理界面: http://localhost:8001 (Resolver)"
        echo "🔧 爬虫服务: http://localhost:8501 (Scraper)"
        ;;
    
    "optimized")
        echo "🔄 切换到优化版本 (轻量级, 212MB)..."
        docker-compose down 2>/dev/null || true
        docker-compose -f docker-compose.optimized.yml down 2>/dev/null || true
        docker-compose -f docker-compose.optimized.yml up -d
        echo "✅ 优化版本启动完成!"
        echo "📊 监控面板: http://localhost:3001 (Grafana)"
        echo "🌐 管理界面: http://localhost:8001 (Resolver)"
        echo "🔧 爬虫服务: http://localhost:8501 (Scraper)"
        ;;
    
    "status")
        echo "📊 当前运行状态:"
        echo "=================="
        
        if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "resolver-optimized\|downloader-optimized\|scraper-optimized"; then
            echo "🟢 当前运行: 优化版本 (轻量级)"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(optimized|test)"
        elif docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "resolver\|downloader\|scraper" | grep -v optimized; then
            echo "🔵 当前运行: 原版本 (完整功能)"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(resolver|downloader|scraper)" | grep -v optimized
        else
            echo "⚪ 当前状态: 没有运行的服务"
        fi
        
        echo ""
        echo "📈 镜像大小对比:"
        echo "原版镜像:"
        docker images | grep "jimwong8/download-cluster" | head -3 2>/dev/null || echo "  (未找到原版镜像)"
        echo "优化版镜像:"
        docker images | grep -E "(downloader:optimized|resolver:optimized|scraper:optimized)" 2>/dev/null || echo "  (未找到优化版镜像)"
        ;;
    
    "stop")
        echo "🛑 停止所有服务..."
        docker-compose down 2>/dev/null || true
        docker-compose -f docker-compose.optimized.yml down 2>/dev/null || true
        echo "✅ 所有服务已停止!"
        ;;
    
    *)
        echo "❌ 错误: 未知版本 '$1'"
        echo "📖 用法: $0 {original|optimized|hub}"
        echo ""
        echo "🔧 可用版本:"
        echo "  original  - 原版本 (5.2GB, 功能完整)"
        echo "  optimized - 优化版本 (212MB, 本地构建)"  
        echo "  hub       - Docker Hub版本 (212MB, 云端镜像)"
        echo ""
        echo "💡 推荐:"
        echo "  开发测试: optimized"
        echo "  生产部署: hub"
        exit 1
        ;;
esac
