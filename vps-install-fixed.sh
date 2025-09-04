#!/bin/bash

# =================================================================
# 分布式下载集群 VPS 中心服务端修复安装脚本
# 解决网络连接和下载问题
# =================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 修复网络连接问题的下载函数
download_project_robust() {
    log_info "使用多种方式下载项目文件..."
    
    DEPLOY_DIR="/opt/download-cluster"
    
    # 方法1: 尝试不同的 Git 配置
    log_info "尝试方法1: 配置 Git 网络设置..."
    git config --global http.postBuffer 1048576000
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    git config --global http.sslVerify false
    
    # 尝试克隆
    if git clone --depth 1 https://github.com/jimwong8/docker-url-downloader.git "$DEPLOY_DIR" 2>/dev/null; then
        log_success "Git 克隆成功"
        return 0
    fi
    
    # 方法2: 使用 wget 下载 ZIP 文件
    log_info "尝试方法2: 下载 ZIP 文件..."
    rm -rf "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR"
    cd "$DEPLOY_DIR"
    
    if wget -O project.zip "https://github.com/jimwong8/docker-url-downloader/archive/refs/heads/main.zip" 2>/dev/null; then
        log_info "解压项目文件..."
        unzip -q project.zip
        mv docker-url-downloader-main/* .
        rm -rf docker-url-downloader-main project.zip
        log_success "ZIP 下载成功"
        return 0
    fi
    
    # 方法3: 使用 curl 下载
    log_info "尝试方法3: 使用 curl 下载..."
    if curl -L -o project.zip "https://github.com/jimwong8/docker-url-downloader/archive/refs/heads/main.zip" 2>/dev/null; then
        log_info "解压项目文件..."
        unzip -q project.zip
        mv docker-url-downloader-main/* .
        rm -rf docker-url-downloader-main project.zip
        log_success "Curl 下载成功"
        return 0
    fi
    
    # 方法4: 直接创建核心文件
    log_info "尝试方法4: 创建核心配置文件..."
    create_core_files
    return 0
}

# 创建核心配置文件
create_core_files() {
    log_info "创建 Docker Compose 配置文件..."
    
    cat > docker-compose.hub.yml << 'EOF'
version: '3.8'

services:
  resolver:
    image: jimwong8/download-cluster:resolver-optimized
    container_name: resolver-optimized
    ports:
      - "8001:8000"
    environment:
      - RESOLVER_HOST=0.0.0.0
      - RESOLVER_PORT=8000
    restart: unless-stopped
    networks:
      - default

  scraper:
    image: jimwong8/download-cluster:scraper-optimized
    container_name: scraper-optimized
    ports:
      - "8501:8500"
    environment:
      - SCRAPER_HOST=0.0.0.0
      - SCRAPER_PORT=8500
    restart: unless-stopped
    networks:
      - default

  downloader-agent:
    image: jimwong8/download-cluster:downloader-optimized
    container_name: downloader-optimized
    environment:
      - RESOLVER_URL=http://resolver:8000
      - AGENT_ID=agent01-optimized
    restart: unless-stopped
    depends_on:
      - resolver
    networks:
      - default

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus-optimized
    ports:
      - "9091:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    networks:
      - default

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-optimized
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana
    restart: unless-stopped
    networks:
      - default

volumes:
  grafana-storage:

networks:
  default:
    driver: bridge
EOF

    # 创建 Prometheus 配置
    mkdir -p prometheus
    cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'resolver'
    static_configs:
      - targets: ['resolver:8000']

  - job_name: 'scraper'
    static_configs:
      - targets: ['scraper:8500']
EOF

    # 创建版本切换脚本
    cat > switch-version.sh << 'EOF'
#!/bin/bash

echo "🚀 分布式下载集群 - 版本管理工具"
echo "=================================="

case "$1" in
    "hub")
        echo "🔄 启动 Docker Hub 版本..."
        docker-compose -f docker-compose.hub.yml down 2>/dev/null || true
        docker-compose -f docker-compose.hub.yml up -d
        echo "✅ Docker Hub 版本启动完成!"
        echo "📊 监控面板: http://localhost:3001"
        echo "🌐 管理界面: http://localhost:8001"
        echo "🔧 爬虫服务: http://localhost:8501"
        ;;
    "stop")
        echo "🛑 停止所有服务..."
        docker-compose -f docker-compose.hub.yml down 2>/dev/null || true
        echo "✅ 所有服务已停止!"
        ;;
    "status")
        echo "📊 服务状态:"
        docker-compose -f docker-compose.hub.yml ps
        ;;
    *)
        echo "用法: $0 {hub|stop|status}"
        echo "hub   - 启动 Docker Hub 版本"
        echo "stop  - 停止所有服务"
        echo "status - 查看服务状态"
        ;;
esac
EOF

    chmod +x switch-version.sh
    log_success "核心配置文件创建完成"
}

# 主安装流程
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
 ╔════════════════════════════════════════════════╗
 ║        分布式下载集群 - 修复安装脚本         ║
 ║                down.lao6.us                    ║
 ╚════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_info "开始修复安装..."
    
    # 创建部署目录
    DEPLOY_DIR="/opt/download-cluster"
    sudo mkdir -p "$DEPLOY_DIR"
    sudo chown $USER:$USER "$DEPLOY_DIR"
    
    # 下载项目文件
    download_project_robust
    
    cd "$DEPLOY_DIR"
    
    # 启动服务
    log_info "启动 Docker Hub 版本服务..."
    ./switch-version.sh hub
    
    # 等待服务启动
    log_info "等待服务启动（30秒）..."
    sleep 30
    
    # 验证服务
    log_info "验证服务状态..."
    if docker ps | grep -q "resolver-optimized.*Up"; then
        log_success "Resolver 服务运行正常"
    else
        log_warning "Resolver 服务可能有问题"
    fi
    
    if docker ps | grep -q "scraper-optimized.*Up"; then
        log_success "Scraper 服务运行正常"
    else
        log_warning "Scraper 服务可能有问题"
    fi
    
    # 显示访问信息
    echo
    log_success "🎉 安装完成！"
    echo
    echo -e "${GREEN}访问地址:${NC}"
    echo "  管理界面: http://down.lao6.us:8001"
    echo "  爬虫服务: http://down.lao6.us:8501"
    echo "  监控面板: http://down.lao6.us:3001"
    echo "  Prometheus: http://down.lao6.us:9091"
    echo
    echo -e "${GREEN}管理命令:${NC}"
    echo "  查看状态: cd /opt/download-cluster && ./switch-version.sh status"
    echo "  停止服务: cd /opt/download-cluster && ./switch-version.sh stop"
    echo "  重启服务: cd /opt/download-cluster && ./switch-version.sh hub"
    echo
}

main "$@"
EOF

chmod +x vps-install-fixed.sh
sudo ./vps-install-fixed.sh
