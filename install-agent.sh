#!/bin/bash

# =================================================================
# 远程下载端一键安装脚本
# 用途: 在各地服务器部署下载代理，连接到中心服务端
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

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
 ╔════════════════════════════════════════════════╗
 ║          分布式下载集群 - 远程下载端          ║
 ║              Remote Download Agent             ║
 ╚════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 <resolver_url> [options]"
    echo ""
    echo "参数:"
    echo "  resolver_url    中心服务端地址 (必需)"
    echo "                  示例: down.lao6.us:8001 或 http://down.lao6.us:8001"
    echo ""
    echo "选项:"
    echo "  --location      代理地理位置 (默认: 自动检测)"
    echo "  --name          代理显示名称 (默认: hostname)"
    echo "  --id            代理唯一标识 (默认: 自动生成)"
    echo "  --port          本地管理端口 (默认: 不开放)"
    echo "  --download-dir  下载目录 (默认: ./downloads)"
    echo "  --max-concurrent 最大并发数 (默认: 5)"
    echo ""
    echo "示例:"
    echo "  $0 down.lao6.us:8001"
    echo "  $0 http://down.lao6.us:8001 --location Beijing --name BJ-Server-01"
    echo "  $0 down.lao6.us:8001 --download-dir /data/downloads --max-concurrent 10"
}

# 解析命令行参数
parse_args() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    RESOLVER_URL="$1"
    shift
    
    # 确保URL格式正确
    if [[ ! "$RESOLVER_URL" =~ ^https?:// ]]; then
        RESOLVER_URL="http://${RESOLVER_URL}"
    fi
    
    # 默认值
    AGENT_LOCATION=$(curl -s ipinfo.io/city 2>/dev/null || echo "Unknown")
    AGENT_NAME=$(hostname)
    AGENT_ID="agent-$(hostname)-$(date +%s)"
    DOWNLOAD_DIR="./downloads"
    MAX_CONCURRENT=5
    MANAGEMENT_PORT=""
    
    # 解析选项
    while [[ $# -gt 0 ]]; do
        case $1 in
            --location)
                AGENT_LOCATION="$2"
                shift 2
                ;;
            --name)
                AGENT_NAME="$2"
                shift 2
                ;;
            --id)
                AGENT_ID="$2"
                shift 2
                ;;
            --port)
                MANAGEMENT_PORT="$2"
                shift 2
                ;;
            --download-dir)
                DOWNLOAD_DIR="$2"
                shift 2
                ;;
            --max-concurrent)
                MAX_CONCURRENT="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        log_info "安装命令: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_warning "Docker Compose 未安装，将使用 docker run 方式部署"
        USE_DOCKER_RUN=true
    else
        USE_DOCKER_RUN=false
    fi
    
    # 检查网络连通性
    log_info "测试与中心服务端的连接..."
    if curl -s --connect-timeout 10 "$RESOLVER_URL" > /dev/null; then
        log_success "网络连接正常"
    else
        log_warning "无法连接到中心服务端，将继续安装（请确保网络配置正确）"
    fi
    
    log_success "系统检查完成"
}

# 创建工作目录
create_workspace() {
    log_info "创建工作目录..."
    
    WORK_DIR="/opt/download-agent-$(echo $AGENT_NAME | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')"
    
    sudo mkdir -p "$WORK_DIR"
    sudo chown $USER:$USER "$WORK_DIR"
    cd "$WORK_DIR"
    
    # 创建下载目录
    mkdir -p downloads logs
    
    log_success "工作目录创建完成: $WORK_DIR"
}

# 生成配置文件
generate_config() {
    log_info "生成配置文件..."
    
    # 创建环境变量文件
    cat > .env << EOF
# 远程下载代理配置
# 生成时间: $(date)

# 中心服务端配置
RESOLVER_URL=$RESOLVER_URL
AGENT_ID=$AGENT_ID
AGENT_NAME=$AGENT_NAME
AGENT_LOCATION=$AGENT_LOCATION

# 下载配置
DOWNLOAD_DIR=/downloads
MAX_CONCURRENT=$MAX_CONCURRENT
CHUNK_SIZE=1048576

# 心跳配置
HEARTBEAT_INTERVAL=30
RETRY_INTERVAL=60

# 日志配置
LOG_LEVEL=INFO
LOG_FORMAT=json
EOF

    if [ "$USE_DOCKER_RUN" = false ]; then
        # 创建 Docker Compose 文件
        cat > docker-compose.yml << EOF
version: '3.8'

services:
  downloader:
    image: jimwong8/download-cluster:downloader-optimized
    container_name: download-agent-$AGENT_NAME
    environment:
      - RESOLVER_URL=\${RESOLVER_URL}
      - AGENT_ID=\${AGENT_ID}
      - AGENT_NAME=\${AGENT_NAME}
      - AGENT_LOCATION=\${AGENT_LOCATION}
      - DOWNLOAD_DIR=\${DOWNLOAD_DIR}
      - MAX_CONCURRENT=\${MAX_CONCURRENT}
      - CHUNK_SIZE=\${CHUNK_SIZE}
      - HEARTBEAT_INTERVAL=\${HEARTBEAT_INTERVAL}
      - RETRY_INTERVAL=\${RETRY_INTERVAL}
      - LOG_LEVEL=\${LOG_LEVEL}
      - LOG_FORMAT=\${LOG_FORMAT}
    volumes:
      - ./downloads:/downloads
      - ./logs:/app/logs
    restart: unless-stopped
    networks:
      - agent-network
EOF

        if [ -n "$MANAGEMENT_PORT" ]; then
            cat >> docker-compose.yml << EOF
    ports:
      - "$MANAGEMENT_PORT:8080"
EOF
        fi

        cat >> docker-compose.yml << EOF

networks:
  agent-network:
    driver: bridge

volumes:
  downloads:
  logs:
EOF
    fi
    
    log_success "配置文件生成完成"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 主管理脚本
    cat > manage.sh << 'EOF'
#!/bin/bash

CONTAINER_NAME="download-agent-$(grep AGENT_NAME .env | cut -d'=' -f2)"
COMPOSE_FILE="docker-compose.yml"

case "$1" in
    start)
        echo "🚀 启动下载代理..."
        if [ -f "$COMPOSE_FILE" ]; then
            docker-compose up -d
        else
            # 使用 docker run 方式
            source .env
            docker run -d \
                --name "$CONTAINER_NAME" \
                --restart unless-stopped \
                -e RESOLVER_URL="$RESOLVER_URL" \
                -e AGENT_ID="$AGENT_ID" \
                -e AGENT_NAME="$AGENT_NAME" \
                -e AGENT_LOCATION="$AGENT_LOCATION" \
                -e DOWNLOAD_DIR="$DOWNLOAD_DIR" \
                -e MAX_CONCURRENT="$MAX_CONCURRENT" \
                -e CHUNK_SIZE="$CHUNK_SIZE" \
                -e HEARTBEAT_INTERVAL="$HEARTBEAT_INTERVAL" \
                -e RETRY_INTERVAL="$RETRY_INTERVAL" \
                -e LOG_LEVEL="$LOG_LEVEL" \
                -e LOG_FORMAT="$LOG_FORMAT" \
                -v "$(pwd)/downloads:/downloads" \
                -v "$(pwd)/logs:/app/logs" \
                jimwong8/download-cluster:downloader-optimized
        fi
        echo "✅ 下载代理启动完成"
        ;;
    stop)
        echo "🛑 停止下载代理..."
        if [ -f "$COMPOSE_FILE" ]; then
            docker-compose down
        else
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm "$CONTAINER_NAME" 2>/dev/null || true
        fi
        echo "✅ 下载代理已停止"
        ;;
    restart)
        echo "🔄 重启下载代理..."
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo "📊 代理状态:"
        if [ -f "$COMPOSE_FILE" ]; then
            docker-compose ps
        else
            docker ps --filter "name=$CONTAINER_NAME"
        fi
        echo ""
        echo "📋 系统信息:"
        echo "CPU: $(nproc) 核"
        echo "内存: $(free -h | awk '/^Mem:/ {print $2}')"
        echo "磁盘: $(df -h . | awk 'NR==2 {print $4 " 可用"}')"
        ;;
    logs)
        echo "📋 查看日志:"
        if [ -f "$COMPOSE_FILE" ]; then
            docker-compose logs -f --tail=100
        else
            docker logs -f --tail=100 "$CONTAINER_NAME"
        fi
        ;;
    update)
        echo "🔄 更新镜像..."
        if [ -f "$COMPOSE_FILE" ]; then
            docker-compose pull
            docker-compose up -d
        else
            docker pull jimwong8/download-cluster:downloader-optimized
            $0 restart
        fi
        echo "✅ 更新完成"
        ;;
    test)
        echo "🧪 测试连接..."
        source .env
        echo "代理ID: $AGENT_ID"
        echo "代理名称: $AGENT_NAME"
        echo "中心服务端: $RESOLVER_URL"
        curl -s "$RESOLVER_URL/api/agents" | grep -q "$AGENT_ID" && \
            echo "✅ 代理已注册" || echo "❌ 代理未注册"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|update|test}"
        echo ""
        echo "start   - 启动代理"
        echo "stop    - 停止代理"
        echo "restart - 重启代理"
        echo "status  - 查看状态"
        echo "logs    - 查看日志"
        echo "update  - 更新镜像"
        echo "test    - 测试连接"
        ;;
esac
EOF

    chmod +x manage.sh
    
    # 健康检查脚本
    cat > health-check.sh << 'EOF'
#!/bin/bash

echo "=== 下载代理健康检查 ==="
echo "时间: $(date)"
echo ""

# 读取配置
source .env

# 检查容器状态
CONTAINER_NAME="download-agent-$AGENT_NAME"
if docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}" | grep -q "$CONTAINER_NAME"; then
    echo "✅ 容器运行正常"
else
    echo "❌ 容器未运行"
    exit 1
fi

# 检查磁盘空间
DISK_USAGE=$(df . | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "⚠️  磁盘使用率过高: ${DISK_USAGE}%"
else
    echo "✅ 磁盘空间充足: ${DISK_USAGE}%"
fi

# 检查内存使用
MEMORY_USAGE=$(docker stats --no-stream --format "table {{.MemUsage}}" $CONTAINER_NAME | tail -1 | awk '{print $1}')
echo "📊 内存使用: $MEMORY_USAGE"

# 检查与中心服务端连接
if curl -s --connect-timeout 5 "$RESOLVER_URL" > /dev/null; then
    echo "✅ 中心服务端连接正常"
else
    echo "❌ 中心服务端连接失败"
fi

# 检查下载目录
DOWNLOAD_COUNT=$(find downloads -type f 2>/dev/null | wc -l)
echo "📁 下载文件数: $DOWNLOAD_COUNT"

echo ""
echo "=== 检查完成 ==="
EOF

    chmod +x health-check.sh
    
    log_success "管理脚本创建完成"
}

# 部署代理
deploy_agent() {
    log_info "部署下载代理..."
    
    # 拉取最新镜像
    log_info "拉取Docker镜像..."
    docker pull jimwong8/download-cluster:downloader-optimized
    
    # 启动代理
    ./manage.sh start
    
    # 等待启动
    log_info "等待代理启动（10秒）..."
    sleep 10
    
    log_success "代理部署完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 检查容器状态
    if ./manage.sh status | grep -q "Up"; then
        log_success "容器运行正常"
    else
        log_error "容器启动失败"
        ./manage.sh logs
        exit 1
    fi
    
    # 测试连接
    sleep 5
    if ./manage.sh test | grep -q "代理已注册"; then
        log_success "代理注册成功"
    else
        log_warning "代理注册失败，请检查网络连接"
    fi
    
    log_success "部署验证完成"
}

# 显示部署信息
show_deployment_info() {
    echo
    log_success "🎉 远程下载代理部署完成！"
    echo
    echo -e "${GREEN}代理信息:${NC}"
    echo "  代理ID: $AGENT_ID"
    echo "  代理名称: $AGENT_NAME"
    echo "  地理位置: $AGENT_LOCATION"
    echo "  中心服务端: $RESOLVER_URL"
    echo "  工作目录: $WORK_DIR"
    echo
    echo -e "${GREEN}管理命令:${NC}"
    echo "  查看状态: ./manage.sh status"
    echo "  查看日志: ./manage.sh logs"
    echo "  重启代理: ./manage.sh restart"
    echo "  健康检查: ./health-check.sh"
    echo "  测试连接: ./manage.sh test"
    echo
    echo -e "${GREEN}监控地址:${NC}"
    echo "  中心服务端: $RESOLVER_URL"
    if [ -n "$MANAGEMENT_PORT" ]; then
        echo "  本地管理: http://localhost:$MANAGEMENT_PORT"
    fi
    echo
    echo -e "${YELLOW}下一步:${NC}"
    echo "  1. 访问中心服务端查看代理注册状态"
    echo "  2. 在中心服务端分配下载任务"
    echo "  3. 定期运行健康检查: crontab -e"
    echo "     */5 * * * * $WORK_DIR/health-check.sh >> /var/log/download-agent.log"
    echo
}

# 主函数
main() {
    show_banner
    parse_args "$@"
    check_requirements
    create_workspace
    generate_config
    create_management_scripts
    deploy_agent
    verify_deployment
    show_deployment_info
}

# 执行主函数
main "$@"
