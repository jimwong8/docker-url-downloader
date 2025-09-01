# URL解析下载系统

一个基于Docker的微服务系统，用于解析和下载需要JavaScript渲染的URL链接。

## 系统架构

### 服务组件

- **URL解析器 (Resolver)**: 使用Playwright浏览器自动化技术解析真实下载链接
- **下载器 (Downloader)**: 使用aria2c进行高性能多线程下载

### 技术栈

- **Resolver服务**:
  - Python 3.11 + FastAPI
  - Playwright (Chromium)
  - 内存缓存 (TTL: 5分钟)
  - 线程池并发处理

- **Downloader服务**:
  - Python 3.11-slim
  - aria2c多线程下载器
  - curl + jq用于API调用

## 快速开始

### 前置要求

- Docker
- Docker Compose

### 启动服务

```bash
# 克隆项目
git clone git@github.com:jimwong8/url-resolver-downloader.git
cd url-resolver-downloader

# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

### 配置环境变量

编辑 `docker-compose.yml` 文件中的环境变量：

```yaml
environment:
  url: "https://你的目标链接"
  dns: "8.8.8.8"
  resolver_endpoint: "http://resolver:8000/resolve"
```

## API文档

### 解析API

**端点**: `POST http://localhost:8000/resolve`

**请求体**:
```json
{
  "url": "https://example.com/signed-url"
}
```

**响应**:
```json
{
  "url": "https://example.com/actual-download-link",
  "headers": {
    "User-Agent": "Mozilla/5.0...",
    "Referer": "https://example.com/signed-url"
  }
}
```

## 目录结构

```
.
├── docker-compose.yml          # 服务编排配置
├── resolver/                   # URL解析服务
│   ├── Dockerfile             # 解析器镜像构建文件
│   └── resolver.py            # FastAPI应用
├── downloader/                # 下载服务
│   ├── Dockerfile            # 下载器镜像构建文件
│   └── entrypoint.sh         # 下载脚本
└── README.md                 # 项目文档
```

## 特性

- ✅ **智能URL解析**: 使用真实浏览器环境解析JavaScript生成的下载链接
- ✅ **高性能下载**: aria2c多线程并发下载
- ✅ **缓存机制**: 5分钟内重复请求直接返回缓存结果
- ✅ **自动重试**: 下载失败自动重试机制
- ✅ **Docker化部署**: 开箱即用的容器化部署
- ✅ **微服务架构**: 服务间松耦合，易于扩展

## 使用场景

- 需要JavaScript执行才能获取真实下载链接的网站
- 通过浏览器动态生成下载URL的服务
- 需要特定User-Agent和Referer头的下载任务
- 批量文件下载和镜像同步

## 监控和日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f resolver
docker-compose logs -f downloader
```

## 性能优化

- Resolver服务使用线程池(最大4个工作线程)处理并发请求
- 内存缓存减少重复解析开销
- 下载器使用2个连接进行分片下载
- 共享内存配置确保Playwright稳定运行

## 故障排除

### 常见问题

1. **Playwright启动失败**
   - 确保为resolver服务分配足够的共享内存 (`shm_size: "1g"`)

2. **下载连接失败**
   - 检查DNS设置和网络连接
   - 验证resolver服务是否正常运行

3. **权限问题**
   - 确保Docker有足够权限访问所需端口

## 开发

### 本地开发环境

```bash
# 安装依赖
cd resolver
pip install fastapi uvicorn playwright pydantic
playwright install chromium

# 启动开发服务器
uvicorn resolver:app --reload --host 0.0.0.0 --port 8000
```

## 许可证

MIT License

## 贡献

欢迎提交Pull Request和Issue！

## 联系方式

- GitHub: [@jimwong8](https://github.com/jimwong8)
- Email: ok008@163.com