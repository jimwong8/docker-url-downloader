#!/bin/bash

echo "=== Docker镜像大小优化对比 ==="
echo ""

# 构建优化版本
echo "🔨 构建优化版本镜像..."

echo "📦 构建downloader优化版..."
cd /home/jimwong/project/docker/download-cluster/downloader
docker build -f Dockerfile.optimized -t downloader:optimized .

echo "📦 构建resolver优化版..."
cd /home/jimwong/project/docker/download-cluster/resolver
docker build -f Dockerfile.optimized -t resolver:optimized .

echo "📦 构建scraper优化版..."
cd /home/jimwong/project/docker/download-cluster/scraper
docker build -f Dockerfile.optimized -t scraper:optimized .

echo ""
echo "📊 大小对比结果:"
echo "===================="

echo ""
echo "🔽 原版镜像大小:"
docker images | grep -E "(download-cluster|url-downloader)" | head -3

echo ""
echo "🔼 优化版镜像大小:"
docker images | grep -E "(downloader:optimized|resolver:optimized|scraper:optimized)"

echo ""
echo "💾 预期优化效果:"
echo "- Downloader: 133MB → ~30MB (减少77%)"
echo "- Resolver: 2.26GB → ~40MB (减少98%)"
echo "- Scraper: 2.79GB → ~150MB (减少95%)"
echo ""
echo "🎯 总优化: ~5GB → ~220MB (减少96%)"
