# 🌐 远程下载端安装指南

## 架构设计
```
中心服务端 (down.lao6.us)
├── Resolver (协调器) - 任务分发和代理管理
├── Scraper (爬虫) - URL解析
├── Monitoring (监控) - 状态监控
└── 管理代理池和下载任务

远程下载端 (各地部署)
├── Downloader Agent - 纯下载功能
├── 自动注册到中心服务端
├── 实时状态汇报
└── 接受中心服务端指令
```

## 🎯 远程下载端特性

### 轻量化设计
- **镜像大小**: 59.8MB (超轻量)
- **内存需求**: 128MB-512MB
- **CPU需求**: 0.5核即可
- **网络需求**: 上行带宽用于状态汇报

### 核心功能
- ✅ **自动注册**: 启动时自动注册到中心服务端
- ✅ **心跳检测**: 定期向中心服务端发送状态
- ✅ **任务接收**: 从中心服务端获取下载任务
- ✅ **进度汇报**: 实时汇报下载进度
- ✅ **故障转移**: 网络中断后自动重连

## 🚀 安装方式

### 方式一：Docker Hub一键部署（推荐）

```bash
# 1. 创建配置目录
mkdir -p /opt/download-agent
cd /opt/download-agent

# 2. 创建配置文件
cat > .env << 'EOF'
# 中心服务端配置
RESOLVER_URL=http://down.lao6.us:8001
AGENT_ID=agent-$(hostname)-$(date +%s)
AGENT_NAME=$(hostname)
AGENT_LOCATION=Default

# 下载配置
DOWNLOAD_DIR=/downloads
MAX_CONCURRENT=5
CHUNK_SIZE=1048576

# 心跳配置
HEARTBEAT_INTERVAL=30
RETRY_INTERVAL=60
EOF

# 3. 创建Docker Compose文件
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  downloader:
    image: jimwong8/download-cluster:downloader-optimized
    container_name: download-agent
    environment:
      - RESOLVER_URL=${RESOLVER_URL}
      - AGENT_ID=${AGENT_ID}
      - AGENT_NAME=${AGENT_NAME}
      - AGENT_LOCATION=${AGENT_LOCATION}
      - DOWNLOAD_DIR=${DOWNLOAD_DIR}
      - MAX_CONCURRENT=${MAX_CONCURRENT}
      - CHUNK_SIZE=${CHUNK_SIZE}
      - HEARTBEAT_INTERVAL=${HEARTBEAT_INTERVAL}
      - RETRY_INTERVAL=${RETRY_INTERVAL}
    volumes:
      - ./downloads:/downloads
      - ./logs:/app/logs
    restart: unless-stopped
    networks:
      - default

networks:
  default:
    driver: bridge

volumes:
  downloads:
EOF

# 4. 启动服务
docker-compose up -d
```

### 方式二：一键安装脚本

```bash
# 下载并运行远程下载端安装脚本
curl -fsSL https://raw.githubusercontent.com/jimwong8/docker-url-downloader/main/install-agent.sh -o install-agent.sh
chmod +x install-agent.sh
sudo ./install-agent.sh down.lao6.us:8001
```

### 方式三：手动Docker运行

```bash
# 单容器运行
docker run -d \
  --name download-agent \
  --restart unless-stopped \
  -e RESOLVER_URL=http://down.lao6.us:8001 \
  -e AGENT_ID=agent-$(hostname) \
  -e AGENT_NAME=$(hostname) \
  -e AGENT_LOCATION="Custom Location" \
  -v ./downloads:/downloads \
  -v ./logs:/app/logs \
  jimwong8/download-cluster:downloader-optimized
```

## 🔧 配置参数说明

### 必需参数
| 参数 | 说明 | 示例 |
|------|------|------|
| `RESOLVER_URL` | 中心服务端地址 | `http://down.lao6.us:8001` |
| `AGENT_ID` | 代理唯一标识 | `agent-beijing-001` |
| `AGENT_NAME` | 代理显示名称 | `Beijing-Server-01` |

### 可选参数
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `AGENT_LOCATION` | `Default` | 代理地理位置 |
| `DOWNLOAD_DIR` | `/downloads` | 下载目录 |
| `MAX_CONCURRENT` | `5` | 最大并发下载数 |
| `CHUNK_SIZE` | `1048576` | 下载块大小(字节) |
| `HEARTBEAT_INTERVAL` | `30` | 心跳间隔(秒) |
| `RETRY_INTERVAL` | `60` | 重试间隔(秒) |

## 📦 批量部署方案

### 1. 多地区部署配置

```bash
# 北京节点
AGENT_ID=agent-beijing-001
AGENT_NAME=Beijing-Primary
AGENT_LOCATION=Beijing-China

# 上海节点  
AGENT_ID=agent-shanghai-001
AGENT_NAME=Shanghai-Primary
AGENT_LOCATION=Shanghai-China

# 广州节点
AGENT_ID=agent-guangzhou-001
AGENT_NAME=Guangzhou-Primary
AGENT_LOCATION=Guangzhou-China

# 海外节点
AGENT_ID=agent-singapore-001
AGENT_NAME=Singapore-Primary
AGENT_LOCATION=Singapore
```

### 2. 自动部署脚本模板

```bash
#!/bin/bash
# deploy-agent.sh

RESOLVER_URL="http://down.lao6.us:8001"
LOCATION="$1"
AGENT_ID="agent-${LOCATION}-$(date +%s)"

if [ -z "$LOCATION" ]; then
    echo "用法: $0 <location>"
    echo "示例: $0 beijing"
    exit 1
fi

mkdir -p /opt/download-agent-${LOCATION}
cd /opt/download-agent-${LOCATION}

cat > docker-compose.yml << EOF
version: '3.8'
services:
  downloader:
    image: jimwong8/download-cluster:downloader-optimized
    container_name: download-agent-${LOCATION}
    environment:
      - RESOLVER_URL=${RESOLVER_URL}
      - AGENT_ID=${AGENT_ID}
      - AGENT_NAME=${LOCATION}-Agent
      - AGENT_LOCATION=${LOCATION}
    volumes:
      - ./downloads:/downloads
      - ./logs:/app/logs
    restart: unless-stopped
EOF

docker-compose up -d
echo "✅ ${LOCATION} 下载代理部署完成"
echo "📊 访问 ${RESOLVER_URL} 查看代理状态"
```

## 🔍 监控和管理

### 1. 查看代理状态

```bash
# 在中心服务端查看
curl http://down.lao6.us:8001/api/agents

# 或访问Web界面
# http://down.lao6.us:8001
```

### 2. 本地代理管理

```bash
# 查看代理状态
docker ps | grep download-agent

# 查看日志
docker logs download-agent -f

# 重启代理
docker restart download-agent

# 查看下载目录
ls -la downloads/

# 查看配置
docker inspect download-agent | grep -A 20 "Env"
```

### 3. 性能监控

```bash
# 查看资源使用
docker stats download-agent

# 查看网络连接
docker exec download-agent netstat -an

# 查看磁盘使用
du -sh downloads/
```

## 🛠️ 故障排除

### 常见问题

1. **代理无法连接中心服务端**
```bash
# 检查网络连通性
curl -I http://down.lao6.us:8001

# 检查防火墙
telnet down.lao6.us 8001
```

2. **代理注册失败**
```bash
# 检查环境变量
docker exec download-agent env | grep RESOLVER

# 查看详细日志
docker logs download-agent --details
```

3. **下载目录权限问题**
```bash
# 修正权限
sudo chown -R 1000:1000 downloads/
sudo chmod -R 755 downloads/
```

## 🚀 高级配置

### 1. 使用自定义网络

```yaml
# docker-compose.yml
version: '3.8'
services:
  downloader:
    image: jimwong8/download-cluster:downloader-optimized
    networks:
      - download-network
    # ... 其他配置

networks:
  download-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### 2. 配置资源限制

```yaml
services:
  downloader:
    image: jimwong8/download-cluster:downloader-optimized
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 128M
          cpus: '0.25'
```

### 3. 健康检查

```yaml
services:
  downloader:
    image: jimwong8/download-cluster:downloader-optimized
    healthcheck:
      test: ["CMD", "curl", "-f", "${RESOLVER_URL}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## 📋 部署清单

- [ ] 确定部署位置和命名规范
- [ ] 配置RESOLVER_URL指向中心服务端
- [ ] 设置唯一的AGENT_ID
- [ ] 创建下载目录并设置权限
- [ ] 启动代理容器
- [ ] 在中心服务端确认代理注册成功
- [ ] 测试下载功能
- [ ] 配置监控和日志

---
🔗 **中心服务端**: http://down.lao6.us:8001  
🐳 **Docker镜像**: jimwong8/download-cluster:downloader-optimized  
📚 **项目文档**: https://github.com/jimwong8/docker-url-downloader
