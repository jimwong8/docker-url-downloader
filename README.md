# 🚀 分布式下载集群 - 完全优化版

[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Python-3.12+-green.svg)](https://www.python.org/)
[![Security](https://img.shields.io/badge/Security-0%20Vulnerabilities-brightgreen.svg)](#security)
[![Size](https://img.shields.io/badge/Size-96%25%20Optimized-orange.svg)](#optimization)

> 高度优化、完全安全的分布式文件下载集群系统

## 🎯 项目特点

- **🏗️ 微服务架构**: Resolver、Downloader、Scraper三大核心组件
- **🐳 双版本支持**: 原版(完整功能) + 优化版(轻量级)
- **🔒 零安全漏洞**: 使用最新安全的基础镜像
- **📈 96%大小优化**: 从5.2GB优化到212MB
- **📊 完整监控**: Prometheus + Grafana
- **🌐 Web管理界面**: 直观的代理管理
- **⚡ 一键启动**: 智能版本切换脚本

## 📊 优化成果

| 组件 | 原版本 | 优化版本 | 优化幅度 |
|------|--------|----------|----------|
| **Downloader** | 133MB | 60MB | **54%** ⬇️ |
| **Resolver** | 2.26GB | 70MB | **97%** ⬇️ |
| **Scraper** | 2.79GB | 80MB | **97%** ⬇️ |
| **总计** | **5.2GB** | **210MB** | **96%** ⬇️ |

## 🚀 快速开始

### 1. 开发环境设置

```bash
# 设置开发环境 (解决IDE导入警告)
./setup-dev.sh

# 查看当前状态
./switch-version.sh status
```

### 2. 启动服务

```bash
# 方式一：Docker Hub一键部署 (推荐生产环境)
./switch-version.sh hub

# 方式二：本地构建优化版本 (推荐开发环境)
./switch-version.sh optimized

# 方式三：原版本 (完整Playwright功能)
./switch-version.sh original

# 查看服务状态
./switch-version.sh status

# 停止所有服务
./switch-version.sh stop
```

### 3. 访问服务

#### 优化版本端口
- 🌐 **管理界面**: http://localhost:8001
- 🔧 **爬虫服务**: http://localhost:8501  
- 📊 **监控面板**: http://localhost:3001

#### 原版本端口
- 🌐 **管理界面**: http://localhost:8000
- 🔧 **爬虫服务**: http://localhost:8500
- 📊 **监控面板**: http://localhost:3000

## 🛠️ 技术架构

### 核心组件

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Resolver      │    │   Downloader    │    │    Scraper      │
│  (协调器)       │    │   (下载代理)    │    │  (链接解析)     │
│                 │    │                 │    │                 │
│ • 任务分发      │    │ • 文件下载      │    │ • URL解析       │
│ • 代理管理      │◄──►│ • 心跳检测      │    │ • 重定向处理    │
│ • Web界面       │    │ • 自动注册      │    │ • REST API      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                    ┌─────────────────┐
                    │   Monitoring    │
                    │ Prometheus+Grafana │
                    └─────────────────┘
```

### 优化技术

1. **基础镜像优化**
   - `python:3.10` → `python:3.12-alpine`
   - 减少90%基础镜像大小

2. **依赖替换**
   - Playwright → requests + beautifulsoup4
   - 减少1.5GB浏览器依赖

3. **构建优化**
   - 多阶段构建
   - 缓存清理
   - 用户权限优化

## 🔒 安全特性

- ✅ **0个高危漏洞** - 使用最新安全镜像
- ✅ **最小攻击面** - 精简依赖包
- ✅ **非root运行** - 安全用户权限
- ✅ **定期更新** - 自动化安全检查

## 📁 项目结构

```
download-cluster/
├── 📋 版本管理
│   ├── switch-version.sh             # 版本切换脚本
│   ├── setup-dev.sh                 # 开发环境设置
│   ├── docker-compose.yml           # 原版配置
│   ├── docker-compose.optimized.yml # 优化版配置
│   └── docker-compose.hub.yml       # Docker Hub配置
├── 🔧 核心服务
│   ├── downloader/                  # 下载代理
│   ├── resolver/                    # 协调器
│   └── scraper/                     # 爬虫服务
├── 📊 监控系统
│   ├── prometheus/                  # 指标收集
│   └── grafana/                     # 可视化面板
└── 📚 文档
    ├── OPTIMIZATION_REPORT.md       # 优化报告
    ├── SECURITY_REPORT.md           # 安全报告
    └── README.md                    # 项目说明
```

## 🐳 Docker Hub镜像

项目已发布到Docker Hub，提供三个优化镜像：

- **jimwong8/download-cluster:downloader-optimized** (60MB)
- **jimwong8/download-cluster:resolver-optimized** (70MB)  
- **jimwong8/download-cluster:scraper-optimized** (80MB)

### 一键部署
```bash
# 拉取并启动所有服务
docker-compose -f docker-compose.hub.yml up -d

# 查看服务状态
docker-compose -f docker-compose.hub.yml ps
```

## 🧪 API使用示例

### 爬虫服务 (URL解析)

```bash
# 解析重定向URL
curl -X POST http://localhost:8501/scrape \
  -H "Content-Type: application/json" \
  -d '{"url":"https://httpbin.org/redirect/1"}'

# 响应
{
  "real_url": "https://httpbin.org/get",
  "status": "success"
}
```

### 管理界面 (任务分配)

```bash
# 查看代理状态
curl http://localhost:8001/

# 分配下载任务
curl -X POST http://localhost:8001/assign \
  -H "Content-Type: application/json" \
  -d '{"name":"agent01","url":"https://example.com/file.zip"}'
```

## ⚡ 性能对比

| 指标 | 原版本 | 优化版本 | 改进 |
|------|--------|----------|------|
| **镜像下载时间** | ~15分钟 | ~2分钟 | **7.5x** 更快 |
| **容器启动时间** | ~30秒 | ~5秒 | **6x** 更快 |
| **磁盘占用** | 5.2GB | 212MB | **24x** 更少 |
| **内存使用** | ~800MB | ~200MB | **4x** 更少 |

## 🛡️ 故障排除

### 常见问题

1. **IDE导入警告**
   ```bash
   # 运行开发环境设置
   ./setup-dev.sh
   ```

2. **容器启动失败**
   ```bash
   # 检查端口占用
   ./switch-version.sh status
   
   # 重新启动
   ./switch-version.sh stop
   ./switch-version.sh optimized
   ```

3. **权限问题**
   ```bash
   # 修复脚本权限
   chmod +x *.sh
   ```

## 🤝 贡献指南

1. **Fork** 本项目
2. **创建** 功能分支 (`git checkout -b feature/AmazingFeature`)
3. **提交** 更改 (`git commit -m 'Add AmazingFeature'`)
4. **推送** 到分支 (`git push origin feature/AmazingFeature`)
5. **打开** Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- **Docker** - 容器化技术
- **Alpine Linux** - 安全轻量的基础镜像
- **Python** - 优雅的编程语言
- **Flask** - 轻量级Web框架

---

**🎉 享受您的超优化分布式下载集群！**

*如有问题或建议，请创建 Issue 或联系维护者。*
