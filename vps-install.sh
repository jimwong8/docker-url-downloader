#!/bin/bash

# =================================================================
# 分布式下载集群 VPS 中心服务端一键安装脚本
# 目标服务器: down.lao6.us
# 项目地址: https://github.com/jimwong8/docker-url-downloader
# =================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
 ╔════════════════════════════════════════════════╗
 ║        分布式下载集群 - VPS服务端部署         ║
 ║                down.lao6.us                    ║
 ╚════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "操作系统: $PRETTY_NAME"
    fi
    
    # 检查内存
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $MEMORY_GB -lt 1 ]]; then
        log_warning "内存不足1GB，可能影响性能"
    else
        log_success "内存检查通过: ${MEMORY_GB}GB"
    fi
    
    # 检查磁盘空间
    DISK_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_GB -lt 5 ]]; then
        log_error "磁盘空间不足5GB，无法继续安装"
        exit 1
    else
        log_success "磁盘空间检查通过: ${DISK_GB}GB 可用"
    fi
}

# 安装Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker 已安装: $(docker --version)"
        return
    fi
    
    log_info "安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    log_success "Docker 安装完成"
}

# 安装Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose 已安装: $(docker-compose --version)"
        return
    fi
    
    log_info "安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose 安装完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian
        sudo ufw allow 8001/tcp  # 管理界面
        sudo ufw allow 8501/tcp  # 爬虫服务
        sudo ufw allow 3001/tcp  # 监控面板
        sudo ufw allow 9091/tcp  # Prometheus
        log_success "UFW 防火墙配置完成"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        sudo firewall-cmd --permanent --add-port=8001/tcp
        sudo firewall-cmd --permanent --add-port=8501/tcp
        sudo firewall-cmd --permanent --add-port=3001/tcp
        sudo firewall-cmd --permanent --add-port=9091/tcp
        sudo firewall-cmd --reload
        log_success "Firewalld 防火墙配置完成"
    else
        log_warning "未检测到防火墙，请手动开放端口: 8001, 8501, 3001, 9091"
    fi
}

# 部署服务
deploy_services() {
    log_info "创建部署目录..."
    DEPLOY_DIR="/opt/download-cluster"
    sudo mkdir -p $DEPLOY_DIR
    sudo chown $USER:$USER $DEPLOY_DIR
    cd $DEPLOY_DIR
    
    log_info "下载项目文件..."
    if [[ -d ".git" ]]; then
        log_info "更新现有项目..."
        git pull origin main
    else
        git clone https://github.com/jimwong8/docker-url-downloader.git .
    fi
    
    log_info "启动服务..."
    chmod +x switch-version.sh
    ./switch-version.sh hub
    
    # 等待服务启动
    log_info "等待服务启动完成..."
    sleep 10
}

# 验证部署
verify_deployment() {
    log_info "验证服务部署..."
    
    cd /opt/download-cluster
    
    # 检查容器状态
    if docker-compose -f docker-compose.hub.yml ps | grep -q "Up"; then
        log_success "容器启动成功"
    else
        log_error "容器启动失败"
        docker-compose -f docker-compose.hub.yml logs
        exit 1
    fi
    
    # 检查服务响应
    sleep 5
    
    if curl -s http://localhost:8001/ > /dev/null; then
        log_success "管理界面响应正常 (端口 8001)"
    else
        log_warning "管理界面响应异常"
    fi
    
    if curl -s http://localhost:3001/ > /dev/null; then
        log_success "监控面板响应正常 (端口 3001)"
    else
        log_warning "监控面板响应异常"
    fi
}

# 创建健康检查脚本
create_health_check() {
    log_info "创建健康检查脚本..."
    
    cat > /opt/download-cluster/health-check.sh << 'EOF'
#!/bin/bash

echo "=== 分布式下载集群健康检查 ==="
echo "时间: $(date)"
echo "服务器: down.lao6.us"
echo

# 检查容器状态
echo "📦 容器状态:"
cd /opt/download-cluster
docker-compose -f docker-compose.hub.yml ps
echo

# 检查服务响应
echo "🌐 服务响应:"
curl -s -o /dev/null -w "管理界面 (8001): %{http_code}\n" http://localhost:8001/ || echo "管理界面 (8001): 连接失败"
curl -s -o /dev/null -w "监控面板 (3001): %{http_code}\n" http://localhost:3001/ || echo "监控面板 (3001): 连接失败"
curl -s -o /dev/null -w "爬虫服务 (8501): %{http_code}\n" http://localhost:8501/ || echo "爬虫服务 (8501): 连接失败"
curl -s -o /dev/null -w "Prometheus (9091): %{http_code}\n" http://localhost:9091/ || echo "Prometheus (9091): 连接失败"
echo

# 检查资源使用
echo "💾 磁盘使用:"
df -h | head -1
df -h | grep -E "(/$|/opt)"
echo

echo "🧠 内存使用:"
free -h
echo

# 检查Docker镜像
echo "🐳 镜像状态:"
docker images | grep jimwong8/download-cluster
echo

echo "=== 检查完成 ==="
EOF
    
    chmod +x /opt/download-cluster/health-check.sh
    log_success "健康检查脚本创建完成"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 服务管理脚本
    cat > /opt/download-cluster/manage.sh << 'EOF'
#!/bin/bash

COMPOSE_FILE="/opt/download-cluster/docker-compose.hub.yml"

case "$1" in
    start)
        echo "启动服务..."
        cd /opt/download-cluster
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    stop)
        echo "停止服务..."
        cd /opt/download-cluster
        docker-compose -f $COMPOSE_FILE down
        ;;
    restart)
        echo "重启服务..."
        cd /opt/download-cluster
        docker-compose -f $COMPOSE_FILE restart
        ;;
    status)
        echo "服务状态..."
        cd /opt/download-cluster
        docker-compose -f $COMPOSE_FILE ps
        ;;
    logs)
        echo "查看日志..."
        cd /opt/download-cluster
        docker-compose -f $COMPOSE_FILE logs -f
        ;;
    update)
        echo "更新服务..."
        cd /opt/download-cluster
        docker-compose -f $COMPOSE_FILE pull
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
EOF
    
    chmod +x /opt/download-cluster/manage.sh
    log_success "管理脚本创建完成"
}

# 显示部署信息
show_deployment_info() {
    echo
    log_success "🎉 分布式下载集群中心服务端部署完成！"
    echo
    echo -e "${GREEN}访问地址:${NC}"
    echo "  管理界面: http://down.lao6.us:8001"
    echo "  爬虫服务: http://down.lao6.us:8501" 
    echo "  监控面板: http://down.lao6.us:3001"
    echo "  Prometheus: http://down.lao6.us:9091"
    echo
    echo -e "${GREEN}管理命令:${NC}"
    echo "  查看状态: /opt/download-cluster/manage.sh status"
    echo "  查看日志: /opt/download-cluster/manage.sh logs"
    echo "  重启服务: /opt/download-cluster/manage.sh restart"
    echo "  健康检查: /opt/download-cluster/health-check.sh"
    echo
    echo -e "${GREEN}项目目录:${NC} /opt/download-cluster"
    echo -e "${GREEN}项目地址:${NC} https://github.com/jimwong8/docker-url-downloader"
    echo
}

# 主函数
main() {
    show_banner
    
    log_info "开始安装分布式下载集群中心服务端..."
    
    check_requirements
    install_docker
    install_docker_compose
    configure_firewall
    deploy_services
    verify_deployment
    create_health_check
    create_management_scripts
    
    show_deployment_info
    
    log_success "安装完成！"
}

# 执行主函数
main "$@"
