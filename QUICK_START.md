# 🚀 快速开始指南

## 一分钟部署 (Docker Hub)

### 1. 一键启动
```bash
# 克隆项目
git clone https://github.com/jimwong8/download-cluster.git
cd download-cluster

# 一键启动 Docker Hub 版本
chmod +x switch-version.sh
./switch-version.sh hub
```

### 2. 验证部署
```bash
# 检查服务状态
docker-compose -f docker-compose.hub.yml ps

# 测试API功能
curl http://localhost:8001/              # 管理界面
curl http://localhost:8501/health        # 爬虫健康检查
```

### 3. 访问服务
- 🌐 **管理界面**: http://localhost:8001
- 🔧 **爬虫服务**: http://localhost:8501  
- 📊 **监控面板**: http://localhost:3001

## 版本选择

| 版本 | 适用场景 | 镜像来源 | 总大小 |
|------|----------|----------|--------|
| `hub` | **生产部署** | Docker Hub | 212MB |
| `optimized` | **开发测试** | 本地构建 | 212MB |
| `original` | **功能对比** | 本地构建 | 5.2GB |

## 常用命令

```bash
# 版本切换
./switch-version.sh hub        # Docker Hub版本
./switch-version.sh optimized  # 本地优化版本
./switch-version.sh original   # 原版本

# 服务管理
./switch-version.sh status     # 查看状态
./switch-version.sh stop       # 停止服务

# 开发环境
./setup-dev.sh                 # 设置Python环境
```

## API使用示例

### 1. URL重定向解析
```bash
curl -X POST http://localhost:8501/scrape \
  -H "Content-Type: application/json" \
  -d '{"url":"https://httpbin.org/redirect/1"}'

# 返回：{"real_url": "https://httpbin.org/get", "status": "success"}
```

### 2. 查看注册代理
```bash
curl http://localhost:8001/
# 显示：agent01-optimized - Last seen: timestamp
```

### 3. 监控指标
```bash
curl http://localhost:9091/metrics | grep download
# 显示：Prometheus监控指标
```

## 故障排除

### 端口冲突
```bash
# 查看端口占用
netstat -tlpn | grep :8001

# 停止冲突服务
./switch-version.sh stop
```

### 服务异常
```bash
# 查看日志
docker-compose -f docker-compose.hub.yml logs resolver
docker-compose -f docker-compose.hub.yml logs scraper

# 重启服务
./switch-version.sh hub
```

### 镜像问题
```bash
# 强制重新拉取
docker-compose -f docker-compose.hub.yml pull
./switch-version.sh hub
```

## 架构优势

✅ **轻量化** - 96%体积减少 (5.2GB→212MB)  
✅ **安全性** - 0个高危漏洞，非root运行  
✅ **便携性** - Docker Hub一键部署  
✅ **监控** - Prometheus+Grafana完整监控  
✅ **扩展** - 支持多代理分布式下载  

---
🔗 **GitHub**: https://github.com/jimwong8/download-cluster  
🐳 **Docker Hub**: https://hub.docker.com/r/jimwong8/download-cluster
