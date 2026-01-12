# OfYann Docker Java

自动构建的 Eclipse Temurin JDK Docker 镜像，支持多版本和自动更新。

## 特性

- ✅ **使用 JDK**: 包含完整的 Java 开发工具（javac, jar 等）
- ✅ **自动构建**: 每日自动检测新版本并构建
- ✅ **镜像最小化**: 使用 jlink 优化，体积约 180-220MB
- ✅ **多版本支持**: Java 8, 17, 21, 25
- ✅ **时区支持**: 默认 Asia/Shanghai，可自定义
- ✅ **中文支持**: 内置 UTF-8 和中文 locale

## 支持的版本

| Java 版本 | 镜像标签 | 说明 |
|-----------|---------|------|
| Java 8 | `ofyann/java:8`, `ofyann/java:8u472b08` | LTS 版本 |
| Java 17 | `ofyann/java:17`, `ofyann/java:17.0.17_10` | LTS 版本 |
| Java 21 | `ofyann/java:21`, `ofyann/java:21.0.9_10` | LTS 版本 |
| Java 25 | `ofyann/java:25`, `ofyann/java:25.0.1_8` | 最新版本 |

**标签说明:**
- `ofyann/java:8` - 大版本最新（会随版本更新）
- `ofyann/java:8u472b08` - 具体小版本（固定不变）

## 快速使用

### 拉取镜像

```bash
# 拉取最新的 Java 17
docker pull ofyann/java:17

# 拉取特定版本
docker pull ofyann/java:17.0.17_10
```

### 运行容器

```bash
# 查看 Java 版本
docker run --rm ofyann/java:17 java -version

# 进入容器
docker run -it --rm ofyann/java:17 bash
```

### 编译 Java 代码

```bash
# 编译
docker run --rm -v "$PWD":/work -w /work ofyann/java:17 javac Main.java

# 运行
docker run --rm -v "$PWD":/work -w /work ofyann/java:17 java Main
```

### 作为基础镜像

```dockerfile
FROM ofyann/java:17

WORKDIR /app
COPY target/myapp.jar app.jar

CMD ["java", "-jar", "app.jar"]
```

## 本地构建

### 前提条件

- Docker 20.10+
- jq (用于解析 JSON)
- curl

### 使用构建脚本

```bash
# 构建 Java 17（自动获取最新版本）
./build.sh 17

# 构建其他版本
./build.sh 8
./build.sh 21
./build.sh 25

# 指定镜像标签
./build.sh 17 myimage:17

# 自定义时区
TIMEZONE=America/New_York ./build.sh 17

# 无缓存构建
NO_CACHE=true ./build.sh 17
```

### 使用 Makefile

```bash
# 查看帮助
make help

# 构建指定版本
make build JAVA_VERSION=17

# 构建所有版本
make build-all

# 测试镜像
make test JAVA_VERSION=17
```

### 使用 Docker 命令

```bash
docker build \
  --build-arg JAVA_MAJOR=17 \
  --build-arg TIMEZONE=Asia/Shanghai \
  -t ofyann/java:17 \
  .
```

## 自定义配置

### 自定义时区

```bash
# 构建时指定
docker build \
  --build-arg TIMEZONE=America/New_York \
  -t ofyann/java:17 \
  .

# 或运行时映射
docker run -e TZ=America/New_York ofyann/java:17 date
```

### 自定义 JLink 模块

减小镜像大小，仅包含需要的模块:

```bash
docker build \
  --build-arg JAVA_MAJOR=17 \
  --build-arg JAVA_MODULES="java.base,java.logging" \
  -t ofyann/java:17-minimal \
  .
```

查看包含的模块:

```bash
docker run --rm ofyann/java:17 java --list-modules
```

## GitHub Actions 自动构建

### 工作流程

1. **每天自动构建**: UTC 00:00 检查新版本
2. **自动检测**: 从 Adoptium API 获取最新版本
3. **增量构建**: 仅构建新版本或更新的版本
4. **双标签**: 同时推送大版本和具体版本标签

### 配置步骤

1. Fork 本仓库

2. 在仓库 Settings → Secrets and variables → Actions 添加:
   - `DOCKERHUB_USERNAME`: Docker Hub 用户名
   - `DOCKERHUB_TOKEN`: Docker Hub 访问令牌

3. 启用 GitHub Actions

4. 推送代码触发首次构建:
   ```bash
   git push origin main
   ```

5. 或手动触发:
   - 访问 Actions 页面
   - 选择 "Docker Build and Push"
   - 点击 "Run workflow"

### 构建触发条件

- ✅ 每天自动检查新版本
- ✅ 推送到 main 分支
- ✅ 手动触发 workflow

## 镜像说明

### 包含的软件

**Java 开发工具:**
- Eclipse Temurin JDK (完整开发工具链)
- `javac` - Java 编译器
- `jar` - JAR 打包工具
- `jdeps` - 依赖分析工具
- `javadoc` - 文档生成工具
- `jlink` - 自定义运行时工具

**系统工具:**
- Tini - 轻量级初始化系统
- curl, wget - 网络工具
- vim, nano - 文本编辑器
- jq - JSON 处理工具

**网络工具:**
- net-tools, iproute2 - 网络配置和诊断
- iputils-ping - 连通性测试
- dnsutils - DNS 查询 (nslookup, dig)
- tcpdump - 网络抓包
- telnet - TCP 连接测试

**系统调试工具:**
- procps, htop - 进程和资源监控
- lsof - 查看打开的文件
- strace - 系统调用追踪
- smem, sysstat - 内存和性能分析

**Java 诊断工具:**
- Arthas - 阿里开源 Java 诊断神器（方法监控、反编译、线程分析等）

**图形支持:**
- X11 支持库（libx11, libxext, libxrender, libxi, libxtst）
- fontconfig - 字体配置

### 环境变量

```bash
JAVA_HOME=/opt/java
PATH=/opt/java/bin:$PATH
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
TZ=Asia/Shanghai  # 默认时区
```

### 镜像大小

包含完整 JDK 开发工具 + 开发调试工具的精简镜像：

- Java 8: ~250MB (手动精简优化 + 工具)
- Java 17: ~300MB (jlink 模块化优化 + 工具)
- Java 21: ~310MB (jlink 模块化优化 + 工具)
- Java 25: ~310MB (jlink 模块化优化 + 工具)

**Java 8 优化说明**:
- 删除源代码 (src.zip, javafx-src.zip)
- 删除示例和演示代码 (demo, sample)
- 删除开发工具 (Mission Control, VisualVM, Derby DB)
- 删除 JavaFX 和 Web Start
- 删除 C 头文件 (include) 和调试符号
- 详细说明见 [JAVA8_OPTIMIZATION.md](JAVA8_OPTIMIZATION.md)

**对比**:
- 官方完整 JDK: ~450MB
- 官方 JRE: ~200MB
- 本镜像: ~200-260MB (完整 JDK 工具链 + 优化)

## 限制说明

### GitHub Actions 限制

- **构建时间**: 每个 job 最多 6 小时
- **存储空间**: 500MB artifacts，删除超过 90 天的
- **并发**: 免费账户 20 个并发 jobs
- **月度分钟**: 免费账户 2000 分钟/月

**建议:**
- 使用缓存减少构建时间
- 按需构建，避免重复构建相同版本
- 定时任务设置合理的频率（每天一次）

### Docker Hub 限制

**免费账户:**
- **镜像数量**: 无限制仓库（公开）
- **私有仓库**: 1 个
- **拉取限制**: 匿名 100 次/6 小时，登录 200 次/6 小时
- **推送限制**: 无限制（但受带宽限制）
- **存储空间**: 无限制（公开镜像）
- **构建时间**: 无自动构建（需付费）

**付费账户 (Pro/Team):**
- **并发构建**: Pro 5 个，Team 15 个
- **自动构建**: 支持
- **拉取限制**: Pro 5000 次/天，Team 无限制

**建议:**
- 使用 GitHub Actions 进行构建而非 Docker Hub 自动构建
- 设置镜像保留策略，删除旧版本
- 避免频繁推送相同标签

### 优化建议

1. **构建缓存**: 使用 GitHub Actions cache 加速构建
2. **增量构建**: 检查镜像是否存在，避免重复构建
3. **并行构建**: matrix 策略并行构建多个版本
4. **标签管理**: 保留必要的版本标签
5. **定时任务**: 合理设置检查频率（建议每天一次）

## 常见问题

### 1. 如何使用具体版本？

使用完整的版本标签确保版本固定:

```dockerfile
FROM ofyann/java:17.0.17_10
```

### 2. 如何查看可用的版本？

```bash
# 访问 Docker Hub
https://hub.docker.com/r/ofyann/java/tags

# 或使用 Docker 命令
docker search ofyann/java
```

### 3. 构建失败怎么办？

检查:
- 是否安装了 jq 和 curl
- 网络连接是否正常
- Adoptium API 是否可访问

```bash
# 测试 API
curl -s "https://api.adoptium.net/v3/assets/latest/17/hotspot" | jq
```

### 4. 如何修改时区？

运行时修改:

```bash
docker run -e TZ=America/New_York ofyann/java:17 date
```

或映射宿主机时区:

```bash
docker run -v /etc/localtime:/etc/localtime:ro ofyann/java:17 date
```

## 项目结构

```
ofyann-docker-java/
├── .github/
│   └── workflows/
│       └── docker-build.yml       # GitHub Actions 工作流
├── Dockerfile                     # 主 Dockerfile
├── build.sh                       # 本地构建脚本
├── test-version-parsing.sh        # 版本解析测试
├── Makefile                       # Make 命令
├── README.md                      # 本文件
├── USAGE.md                       # 使用示例
├── TOOLS.md                       # 开发调试工具说明
├── CHANGELOG.md                   # 更新日志
├── FIXES.md                       # 问题修复记录
├── JAVA8_OPTIMIZATION.md          # Java 8 优化说明
├── .dockerignore                  # Docker 忽略文件
└── .gitignore                     # Git 忽略文件
```

## 许可证

MIT License

## 相关链接

- [Eclipse Temurin](https://adoptium.net/)
- [Docker Hub](https://hub.docker.com/r/ofyann/java)
- [GitHub Repository](https://github.com/ofyann/ofyann-docker-java)
