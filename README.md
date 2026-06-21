# OfYann Docker Java

自动构建的 Eclipse Temurin JDK Docker 镜像，支持多版本和自动更新。

## 特性

- ✅ **两个版本可选**（均为完整 JDK，保留全部 `java.*`/`jdk.*` 模块，不再用 jlink 裁剪，避免缺模块运行异常；由同一 Dockerfile 的不同 build target 实现）:
  - **完整版**（`--target full`）: 含 Arthas 诊断工具与开发工具，约 230-260MB
  - **精简版**（`--target minimal`）: 纯运行时环境，无 Arthas/编辑器，约 190-210MB
- ✅ **多架构支持**: `linux/amd64`、`linux/arm64`，CI 自动构建多架构 manifest
- ✅ **自动构建**: 每周自动检测新版本并多架构构建，也可手动触发
- ✅ **多版本支持**: Java 8, 17, 21, 25
- ✅ **供应链校验**: 下载 JDK 时按架构校验 SHA256（取自 Adoptium API）
- ✅ **时区支持**: 默认 Asia/Shanghai，可自定义
- ✅ **UTF-8 与中文支持**: 默认 `en_US.UTF-8`（中文显示正常），完整版额外生成 `zh_CN.UTF-8` 可切换中文 locale 语义
- ✅ **时区**: 默认 `Asia/Shanghai`(+08)，同时设置 `TZ` 环境变量与 `/etc/localtime`，跨 JDK 版本可靠

## 支持的版本

> 下表中的具体小版本号（如 `17.0.17_10`）为示例，实际版本由 Adoptium API 动态获取，以 [Docker Hub tags](https://hub.docker.com/r/ofyann/java/tags) 为准。

### 完整版（带 Arthas）

| Java 版本 | 镜像标签 | 说明 |
|-----------|---------|------|
| Java 8 | `ofyann/java:temurin-8`, `ofyann/java:temurin-8u472b08` | LTS 版本 |
| Java 17 | `ofyann/java:temurin-17`, `ofyann/java:temurin-17.0.17_10` | LTS 版本 |
| Java 21 | `ofyann/java:temurin-21`, `ofyann/java:temurin-21.0.9_10` | LTS 版本 |
| Java 25 | `ofyann/java:temurin-25`, `ofyann/java:temurin-25.0.1_8` | 最新版本 |

### 精简版（纯运行时）

| Java 版本 | 镜像标签 | 说明 |
|-----------|---------|------|
| Java 8 | `ofyann/java:temurin-8-minimal` | LTS 精简版 |
| Java 17 | `ofyann/java:temurin-17-minimal` | LTS 精简版 |
| Java 21 | `ofyann/java:temurin-21-minimal` | LTS 精简版 |
| Java 25 | `ofyann/java:temurin-25-minimal` | 精简版 |

**标签说明:**
- `ofyann/java:temurin-8` - 完整版，大版本最新（会随版本更新）
- `ofyann/java:temurin-8-minimal` - 精简版，大版本最新
- `ofyann/java:temurin-8u472b08` - 完整版，具体小版本（固定不变）

### 镜像命名规则

所有镜像遵循统一命名：`ofyann/java:<distro>-<version>[-<variant>]`

- `<distro>`：JDK 发行版（`temurin` / `zulu` / `corretto` / `liberica` 等，当前仅 `temurin`）
- `<version>`：Java 大版本（`8`/`17`/`21`/`25`，滚动）或具体小版本（`17.0.19_10`、`8u492b09`，固定）
- `<variant>`：可选变体，省略=完整版；`-minimal`=精简运行时
- 架构不进标签，通过多架构 manifest list 自动选择（amd64/arm64）

> **迁移提示**：早期版本使用过无 distro 前缀的旧标签（如 `ofyann/java:17`），现已弃用不再更新。请在 `FROM` 中迁移到 `ofyann/java:temurin-17`。完整规则见 [AGENTS.md §6](./AGENTS.md)。

## 快速使用

### 拉取镜像

```bash
# 拉取完整版（带 Arthas 诊断工具）
docker pull ofyann/java:temurin-17

# 拉取精简版（纯运行时，更小体积）
docker pull ofyann/java:temurin-17-minimal

# 拉取特定版本
docker pull ofyann/java:temurin-17.0.17_10
```

### 运行容器

```bash
# 查看 Java 版本
docker run --rm ofyann/java:temurin-17 java -version

# 进入容器（完整版有 vim 等工具）
docker run -it --rm ofyann/java:temurin-17 bash

# 进入精简版容器（工具较少）
docker run -it --rm ofyann/java:temurin-17-minimal bash
```

### 作为基础镜像

```dockerfile
# 生产环境：使用精简版（体积更小）
FROM ofyann/java:temurin-17-minimal

WORKDIR /app
COPY target/myapp.jar app.jar

CMD ["java", "-jar", "app.jar"]
```

```dockerfile
# 开发/调试环境：使用完整版（带 Arthas）
FROM ofyann/java:temurin-17

WORKDIR /app
COPY target/myapp.jar app.jar

# 可以使用 Arthas 进行诊断
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
# 构建完整版（带 Arthas）— 默认按宿主架构自动获取 JDK；默认 target 即 full
docker build \
  --build-arg JAVA_MAJOR=17 \
  --build-arg TIMEZONE=Asia/Shanghai \
  -t ofyann/java:temurin-17 \
  .

# 构建精简版（纯运行时）
docker build \
  --target minimal \
  --build-arg JAVA_MAJOR=17 \
  --build-arg TIMEZONE=Asia/Shanghai \
  -t ofyann/java:temurin-17-minimal \
  .

# 多架构构建（需 buildx + QEMU）
docker buildx build \
  --target full \
  --platform linux/amd64,linux/arm64 \
  --build-arg JAVA_MAJOR=17 \
  -t ofyann/java:temurin-17 \
  --push .
```

> 说明：Dockerfile 收到 `JAVA_URL`/`JAVA_SHA256` 时直接使用（build.sh 本地构建按宿主架构传入）；未传入时按 `TARGETARCH` 自动从 Adoptium API 获取对应架构的下载直链与校验和（多架构构建用此路径）。

## 自定义配置

### 自定义时区

```bash
# 构建时指定
docker build \
  --build-arg TIMEZONE=America/New_York \
  -t ofyann/java:temurin-17 \
  .

# 或运行时映射
docker run -e TZ=America/New_York ofyann/java:temurin-17 date
```

### 模块说明

镜像不再使用 jlink 裁剪，而是保留完整的 Eclipse Temurin JDK（仅删除源码/文档/示例/法律文件/调试符号等非模块内容）。因此包含全部 `java.*`/`jdk.*` 模块，不会出现因缺模块（如 `java.net.http`、`java.desktop`、`java.scripting`、`jdk.zipfs` 等）导致的运行异常。

查看包含的模块:

```bash
docker run --rm ofyann/java:temurin-17 java --list-modules
```

## GitHub Actions 自动构建

### 工作流程

1. **每周自动构建**: 每周一 UTC 00:00 全量多架构构建并推送（也可手动触发）
2. **自动检测**: 从 Adoptium API 获取最新版本号（用于打具体版本标签；下载直链与 SHA256 由 Dockerfile 按架构自行获取）
3. **增量构建**: 仅构建新版本或更新的版本（通过 manifest 检查跳过已存在的多架构镜像）
4. **多架构**: 单次 buildx 构建同时产出 amd64 / arm64
5. **双标签**: 同时推送大版本和具体版本标签

> 注：push 到 main **不会**触发构建，仅定时任务（每周一）与手动触发（Actions → Run workflow）会构建并推送镜像。

### 配置步骤

1. Fork 本仓库

2. 在仓库 Settings → Secrets and variables → Actions 添加:
   - `DOCKERHUB_USERNAME`: Docker Hub 用户名
   - `DOCKERHUB_TOKEN`: Docker Hub 访问令牌

3. 启用 GitHub Actions

4. 推送代码后，首次构建需手动触发（push 不自动构建）:
   - 访问 Actions 页面
   - 选择 "Docker Build and Push"
   - 点击 "Run workflow"（可勾选 `force_build` 强制重建所有版本）

### 构建触发条件

- ✅ 每周一 UTC 00:00 自动检查新版本（schedule）
- ✅ 手动触发 workflow（workflow_dispatch，可强制重建）
- ❌ push 到 main 不触发构建（避免每次推送都消耗多架构 QEMU 构建额度）

## 镜像说明

### 包含的软件

#### 完整版（Dockerfile `--target full`）

**Java:**
- Eclipse Temurin **完整 JDK**（不再使用 jlink 裁剪，保留全部 `java.*`/`jdk.*` 模块与 `javac` 等开发工具）
- 仅删除源码、文档、示例、法律文件、调试符号等非模块内容
- 包含 Arthas 所需模块：`jdk.attach`、`jdk.jdi`、`jdk.compiler` 等（完整 JDK 天然具备）

**系统工具:**
- Tini - 轻量级初始化系统
- curl - 网络下载工具
- vim - 文本编辑器
- less - 文件查看器
- unzip, zip - 压缩工具
- jq - JSON 处理工具

**网络诊断工具:**
- iproute2 - 网络配置和诊断（ip 命令）
- iputils-ping - 连通性测试（ping）

**系统调试工具:**
- procps - 进程和资源监控（ps, top, free, vmstat）
- lsof - 查看打开的文件

**Java 诊断工具:**
- Arthas - 阿里开源 Java 诊断神器（方法监控、反编译、线程分析等）

**字体支持:**
- fontconfig - 字体配置（Java GUI 应用必需）

**语言支持:**
- UTF-8 编码（中文显示正常）
- 生成 `en_US.UTF-8` 与 `zh_CN.UTF-8`，默认 `LANG=en_US.UTF-8`，可 `docker run -e LANG=zh_CN.UTF-8` 切换中文 locale 语义

---

#### 精简版（Dockerfile `--target minimal`）

**Java:**
- Eclipse Temurin **完整 JDK**（与完整版相同的裁剪策略，保留全部模块与 `javac`）
- 仅删除非模块内容，不含 Arthas 与编辑器等附加工具

**系统工具:**
- Tini - 轻量级初始化系统
- curl - 网络下载工具

**网络诊断工具:**
- iproute2 - 网络配置和诊断（ip 命令）
- iputils-ping - 连通性测试（ping）

**系统调试工具:**
- procps - 进程和资源监控（ps, top, free, vmstat）
- lsof - 查看打开的文件

**字体支持:**
- fontconfig - 字体配置

**语言支持:**
- UTF-8 编码（中文显示正常）
- 仅生成 `en_US.UTF-8`（为减体积，不含 `zh_CN` locale；如需中文 locale 语义请用完整版）

**不包含:**
- ❌ Arthas（无法使用 Java 诊断功能）
- ❌ vim（无编辑器）
- ❌ zip/unzip（无压缩工具）
- ❌ jq（无 JSON 工具）
- ❌ 中文 locale

> 注：精简版同样包含完整 JDK（含 `javac`），仅减少了附加系统工具与 Arthas。

### 环境变量

```bash
JAVA_HOME=/opt/java
PATH=/opt/java/bin:/opt/arthas:$PATH   # 完整版含 /opt/arthas；精简版为 /opt/java/bin:$PATH
LANG=en_US.UTF-8                         # UTF-8 编码，中文显示正常
LANGUAGE=en_US:en
TZ=Asia/Shanghai                         # 显式时区，与 /etc/localtime 一致，跨 JDK 版本兜底 +8
```

> 关于 locale：默认 `en_US.UTF-8`。**UTF-8 编码下中文字符显示正常**，与 locale 数量无关。
> 区别在于 Locale 语义：日期/数字格式化、异常消息语言默认英文。
> 完整版同时生成 `zh_CN.UTF-8`，运行时可切换中文 locale 语义：
> ```bash
> docker run -e LANG=zh_CN.UTF-8 ofyann/java:temurin-17
> ```
> 精简版仅生成 `en_US.UTF-8`（为减体积），如需中文 locale 语义请用完整版。

### 镜像大小

> 以下为估算值（基于裁剪后的完整 JDK + Debian slim），实际以 Docker Hub 为准。各架构体积相近。

#### 完整版（带 Arthas 和开发工具）

- Java 8: ~230MB
- Java 17: ~240MB
- Java 21: ~250MB
- Java 25: ~250MB

#### 精简版（纯运行时，无 Arthas/编辑器）

- Java 8: ~190MB
- Java 17: ~200MB
- Java 21: ~210MB
- Java 25: ~210MB

**对比**:
- 官方完整 JDK: ~450MB
- 完整版: ~230-250MB（节省约 45%）
- 精简版: ~190-210MB（节省约 53%）

**优化手段**:
- 删除源码、文档、示例、法律文件、调试符号
- 删除 `jmods`（运行时不需要，模块已在 `lib/modules`）
- 多阶段构建，构建依赖不进入最终镜像

## 限制说明

### 架构支持

CI 同时构建并推送 **`linux/amd64`**、**`linux/arm64`** 两种架构的镜像（同一标签的多架构 manifest list，`docker pull` 会自动选择匹配宿主的架构）。

- amd64：GitHub runner 原生构建
- arm64：通过 QEMU 仿真构建，速度较慢但功能完整
- arm64 的运行时测试仅验证构建成功（QEMU 仿真运行较慢，不单独跑测试套件）
- 不含 arm/v7（armv7）：QEMU 仿真下 java 二进制 interpreter 解析不稳定，官方镜像亦常如此取舍

### GitHub Actions 限制

- **构建时间**: 每个 job 最多 6 小时
- **存储空间**: 500MB artifacts，删除超过 90 天的
- **并发**: 免费账户 20 个并发 jobs
- **月度分钟**: 免费账户 2000 分钟/月

**建议:**
- 使用缓存减少构建时间
- 按需构建，避免重复构建相同版本
- 定时任务设置合理的频率（每周一次，多架构 QEMU 构建成本较高）

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
5. **定时任务**: 合理设置检查频率（建议每周一次，多架构 QEMU 构建成本较高）

## 常见问题

### 1. 如何使用具体版本？

使用完整的版本标签确保版本固定:

```dockerfile
FROM ofyann/java:temurin-17.0.17_10
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
docker run -e TZ=America/New_York ofyann/java:temurin-17 date
```

或映射宿主机时区:

```bash
docker run -v /etc/localtime:/etc/localtime:ro ofyann/java:temurin-17 date
```

## 版本选择建议

### 什么时候使用完整版？

- ✅ 需要使用 Arthas 进行线上诊断和问题排查
- ✅ 需要在容器内编辑配置文件（vim）
- ✅ 需要处理压缩文件或 JSON 数据
- ✅ 需要中文字符显示支持
- ✅ 开发和测试环境

### 什么时候使用精简版？

- ✅ 生产环境运行 Java 应用（追求极致体积）
- ✅ 不需要在线诊断工具
- ✅ 容器编排环境（Kubernetes）需要快速拉取
- ✅ 带宽和存储受限的场景
- ✅ 仅需要运行 jar/war 包

## 项目结构

```
ofyann-docker-java/
├── .github/
│   └── workflows/
│       └── docker-build.yml       # GitHub Actions 工作流
├── Dockerfile                     # 单 Dockerfile 双 target：full（带 Arthas）/ minimal（纯运行时）
├── build.sh                       # 本地构建脚本（自动获取版本，按 target 切换变体）
├── Makefile                       # Make 命令
├── README.md                      # 本文件
├── TOOLS.md                       # 开发调试工具说明
├── CHANGELOG.md                   # 更新日志
├── AGENTS.md                      # AI 助手项目上下文
├── CLAUDE.md                      # 指向 AGENTS.md
├── LICENSE                        # MIT
├── .dockerignore                  # Docker 忽略文件
└── .gitignore                     # Git 忽略文件
```

## 许可证

MIT License

## 相关链接

- [Eclipse Temurin](https://adoptium.net/)
- [Docker Hub](https://hub.docker.com/r/ofyann/java)
- [GitHub Repository](https://github.com/ofyann/ofyann-docker-java)
