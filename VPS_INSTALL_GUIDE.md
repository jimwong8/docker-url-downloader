# 🚀 VPS中心服务端安装指南

## 目标服务器
- **VPS地址**: down.lao6.us
- **部署内容**: 分布式下载集群中心服务端
- **服务包括**: Resolver (协调器) + Scraper (爬虫) + 监控系统

## 🔧 前置要求

### 1. 系统要求
```bash
# Ubuntu/Debian 推荐
- CPU: 1核以上
- 内存: 1GB以上  
- 硬盘: 5GB可用空间
- 网络: 公网IP，开放端口 8001, 8501, 3001, 9091
```

### 2. 必需软件
```bash
# 安装 Docker 和 Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以应用docker组权限
exit
```

## 📦 一键部署脚本

### 方式一：GitHub克隆 + Docker Hub镜像（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/jimwong8/docker-url-downloader.git
cd docker-url-downloader

# 2. 启动中心服务端
chmod +x switch-version.sh
./switch-version.sh hub

# 3. 验证服务
curl http://localhost:8001/              # 管理界面
curl http://localhost:8501/health        # 爬虫健康检查
```

### 方式二：直接Docker Compose部署

```bash
# 1. 创建项目目录
mkdir -p /opt/download-cluster
cd /opt/download-cluster

# 2. 下载配置文件
wget https://raw.githubusercontent.com/jimwong8/docker-url-downloader/main/docker-compose.hub.yml

# 3. 启动服务
docker-compose -f docker-compose.hub.yml up -d

# 4. 查看状态
docker-compose -f docker-compose.hub.yml ps
```

## 🌐 服务端口配置

### 内部服务端口
```bash
服务名称          内部端口    外部端口    说明
resolver         8000       8001       Web管理界面
scraper          8500       8501       爬虫API服务
prometheus       9090       9091       监控数据收集
grafana          3000       3001       监控可视化面板
```

### 防火墙配置
```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 8001/tcp    # 管理界面
sudo ufw allow 8501/tcp    # 爬虫服务
sudo ufw allow 3001/tcp    # 监控面板
sudo ufw allow 9091/tcp    # Prometheus

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=8001/tcp
sudo firewall-cmd --permanent --add-port=8501/tcp
sudo firewall-cmd --permanent --add-port=3001/tcp
sudo firewall-cmd --permanent --add-port=9091/tcp
sudo firewall-cmd --reload
```

## 🔧 生产环境配置

### 1. 反向代理 (Nginx)
```nginx
# /etc/nginx/sites-available/download-cluster
server {
    listen 80;
    server_name down.lao6.us;

    # 管理界面
    location / {
        proxy_pass http://localhost:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 爬虫API
    location /api/ {
        proxy_pass http://localhost:8501/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 监控面板
    location /monitor/ {
        proxy_pass http://localhost:3001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 2. 启用反向代理
```bash
sudo ln -s /etc/nginx/sites-available/download-cluster /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 3. SSL证书 (Let's Encrypt)
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d down.lao6.us
```

## 📊 服务验证

### 1. 健康检查脚本
```bash
#!/bin/bash
# health-check.sh

echo "=== 分布式下载集群健康检查 ==="
echo "时间: $(date)"
echo

# 检查容器状态
echo "📦 容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

# 检查服务响应
echo "🌐 服务响应:"
curl -s -o /dev/null -w "管理界面 (8001): %{http_code}\n" http://localhost:8001/
curl -s -o /dev/null -w "爬虫服务 (8501): %{http_code}\n" http://localhost:8501/health || echo "爬虫服务 (8501): 检查失败"
curl -s -o /dev/null -w "监控面板 (3001): %{http_code}\n" http://localhost:3001/
curl -s -o /dev/null -w "Prometheus (9091): %{http_code}\n" http://localhost:9091/
echo

# 检查磁盘使用
echo "💾 磁盘使用:"
df -h | grep -E "(/$|/opt)"
echo

# 检查内存使用
echo "🧠 内存使用:"
free -h
echo

echo "=== 检查完成 ==="
```

### 2. 设置定时检查
```bash
chmod +x health-check.sh
# 添加到crontab，每5分钟检查一次
echo "*/5 * * * * /opt/download-cluster/health-check.sh >> /var/log/download-cluster-health.log 2>&1" | crontab -
```

## 🛠️ 运维管理

### 常用命令
```bash
# 查看服务状态
docker-compose -f docker-compose.hub.yml ps

# 查看日志
docker-compose -f docker-compose.hub.yml logs resolver
docker-compose -f docker-compose.hub.yml logs scraper

# 重启服务
docker-compose -f docker-compose.hub.yml restart

# 更新镜像
docker-compose -f docker-compose.hub.yml pull
docker-compose -f docker-compose.hub.yml up -d

# 停止服务
docker-compose -f docker-compose.hub.yml down
```

### 备份配置
```bash
# 备份脚本
#!/bin/bash
BACKUP_DIR="/backup/download-cluster-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# 备份配置文件
cp docker-compose.hub.yml $BACKUP_DIR/
cp -r prometheus/ $BACKUP_DIR/
cp -r grafana/ $BACKUP_DIR/

# 备份数据卷
docker run --rm -v download-cluster_grafana-storage:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/grafana-data.tar.gz -C /data .

echo "备份完成: $BACKUP_DIR"
```

## 🚀 访问地址

部署完成后，通过以下地址访问：

- **管理界面**: http://down.lao6.us:8001
- **爬虫服务**: http://down.lao6.us:8501  
- **监控面板**: http://down.lao6.us:3001
- **Prometheus**: http://down.lao6.us:9091

如果配置了Nginx反向代理：
- **管理界面**: https://down.lao6.us/
- **爬虫API**: https://down.lao6.us/api/
- **监控面板**: https://down.lao6.us/monitor/

## 🔥 故障排除

### 常见问题
1. **端口被占用**: `netstat -tlpn | grep 8001` 检查端口
2. **权限问题**: 确保用户在docker组中
3. **内存不足**: 检查 `free -h` 和 `docker stats`
4. **网络问题**: 检查防火墙和安全组设置

### 紧急重启
```bash
# 完全重启
docker-compose -f docker-compose.hub.yml down
docker system prune -f
docker-compose -f docker-compose.hub.yml up -d
```

---
📞 **技术支持**: 如有问题请检查 `/var/log/download-cluster-health.log`  
🔗 **项目地址**: https://github.com/jimwong8/docker-url-downloader  
🐳 **镜像仓库**: https://hub.docker.com/r/jimwong8/download-cluster
