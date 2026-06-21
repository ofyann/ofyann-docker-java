# 更新日志

## [2.5.0] - 2026-06-22

### 升级

- 🔧 **GitHub Actions 全部升级到最新主版本（Node 24 运行时）**，彻底消除 Node 20 弃用警告：
  - `actions/checkout` v5 → v7
  - `docker/setup-qemu-action` v3 → v4
  - `docker/setup-buildx-action` v3 → v4
  - `docker/login-action` v3 → v4
  - `docker/build-push-action` v6 → v7
- 🔧 **Arthas 升级** 4.1.5 → 4.3.0（zip 结构不变，安装逻辑无需改动）
  - tini 保持 v0.19.0（krallin/tini 仓库最新且为最终版本，项目已不活跃）

## [2.4.0] - 2026-06-22

### 修复

- 🐛 **修复 arm/v7 构建失败（exit 127）**：QEMU 仿真下 arm/v7 平台的 java 二进制因 ELF interpreter（`ld-linux-armhf.so.3`）解析失败报 `/opt/jdk/bin/java: not found`。CI 移除 `linux/arm`，仅保留 `linux/amd64,linux/arm64`（官方镜像亦常如此取舍）
- 🐛 **移除 push 触发构建**：push 到 main 不再触发 CI 构建（避免每次推送消耗多架构 QEMU 构建额度）；仅保留 schedule（每周一）与 workflow_dispatch（手动）触发构建并推送
- 🔧 **升级 actions 修复 Node 20 弃用警告**：`actions/checkout@v4`→`v5`、`docker/build-push-action@v5`→`v6`（Node 24 主版本）

### 变更

- 📝 README/AGENTS 同步：架构改为 amd64+arm64，触发条件改为 schedule+手动，注明 push 不构建

## [2.3.0] - 2026-06-21

### 重大变更（镜像命名规则）

- 🔄 **统一镜像命名规则**：所有标签改为 `ofyann/java:<distro>-<version>[-<variant>]`
  - 新增发行版前缀，为后续支持 Zulu/Corretto/Liberica 等多发行版预留，避免撞车
  - **不保留旧无前缀标签作为别名**，旧标签 `ofyann/java:17` 等不再产生新版本（已发布镜像仍可拉取）
  - 迁移：`ofyann/java:17` → `ofyann/java:temurin-17`，`ofyann/java:17-minimal` → `ofyann/java:temurin-17-minimal`
  - 架构不进标签，统一用多架构 manifest list
- 📝 AGENTS.md 新增第 6 章「镜像命名规则」，含核心格式、标签类型、示例矩阵、迁移说明、扩展新发行版步骤、命名约定
- 🏗️ CI matrix 增加 `distro` 字段，标签生成全部加 `temurin-` 前缀；build.sh 支持 `DISTRO` 环境变量；Makefile 增加 `DISTRO` 与 `TAG` 变量
- 📝 README 全部示例迁移到新标签，新增命名规则说明与迁移提示

## [2.2.0] - 2026-06-21

### 重构

- 🔄 **合并双 Dockerfile 为单文件 + build target**
  - 原 `Dockerfile`（完整版）+ `Dockerfile.minimal`（精简版）合并为单 `Dockerfile`，三阶段：`jdk-builder`（共享）→ `minimal` → `full`（继承 minimal 叠加 Arthas/工具/zh_CN）
  - 用 `--target full` / `--target minimal` 切换变体，消除双份维护漂移风险（改 JDK 裁剪逻辑只需改一处）
  - build.sh 与 CI 改用 `--target`，删除 `Dockerfile.minimal`

### 修复

- 🐛 **JFR 回归**：从 jlink 切到完整 JDK 后，`jdk.jfr` 模块进入 `lib/modules`，但 `lib/jfr/default.jfc` 配置文件仍在裁剪列表中被删，导致 `jcmd JFR.start` 找不到默认配置失败。从裁剪列表移除 `lib/jfr` 与 `include`（JNI 头文件）
- 🐛 **build.sh 版本校验注入**：原正则 `[[ =~ ]]` 未锚定，`./build.sh "8 17"` 或 `.*` 可绕过校验后拼出错误 URL。改为先校验纯数字、再列表精确匹配
- 🐛 **build.sh MINIMAL_TAG 畸形**：无冒号的自定义 `IMAGE_TAG` 生成畸形标签，改为按含冒号/后缀分类处理
- 🐛 **build.sh 测试门失效**：`build_image` 在 `if !` 上下文中 `set -e` 被挂起，构建后 `docker run` 测试失败不会中断。测试加 `|| return 1` 显式处理
- 🐛 **版本解析脆弱**：build.sh 优先用 Adoptium API 结构化字段 `version.major/minor/security/build`，回退到 semver+sed

### 优化

- ⚡ **CI 成本控制**：schedule 从每日改为每周（避免每日 4版本×2变体×3架构 QEMU 构建撑爆免费额度）；push 事件仅 `linux/amd64` 构建验证不推送（`load=true`），不耗 QEMU、不污染镜像仓库；schedule/dispatch 全架构构建推送

## [2.1.1] - 2026-06-21

### 修复（本地化与时区）

- 🐛 **JFR 回归**：从 jlink 切到完整 JDK 后，`jdk.jfr` 模块进入 `lib/modules`，但 `lib/jfr/default.jfc` 配置文件仍在裁剪列表中被删，导致 `jcmd JFR.start` 找不到默认配置失败（模块在、配置没的损坏中间态）。从裁剪列表移除 `lib/jfr` 与 `include`（JNI 头文件，支持 `javac -h`）

### 修复（本地化与时区）

- 🐛 **新增 `TZ` 环境变量**：原镜像仅靠 `/etc/localtime` 软链设置时区，JDK 8 在部分场景下时区探测脆弱可能回退 UTC。现同时设置 `ENV TZ=${TIMEZONE}` 与 `/etc/localtime`，跨 JDK 版本可靠兜底 +8 时区
- 🐛 **移除强制的 `LC_ALL`**：原 `LC_ALL=en_US.UTF-8` 优先级最高，会压过运行时 `-Duser.language` 及用户 `docker run -e LANG=zh_CN.UTF-8` 的 locale 切换意图。改为只设 `LANG`，保留切换能力
- 🐛 **构建期增加 locale/tz 验证**：`RUN` 中校验 `en_US.utf8`/`zh_CN.utf8`(完整版) 已生成、时区文件就位，避免 `locale-gen` 静默失败导致 LANG 回退为 C（中文输出乱码）
- 🐛 **CI 时区/locale 测试增加断言**：原仅 `date +%Z` 打印不校验，现断言 `date +%z == +0800`、Java `ZonedDateTime` 含 `+08:00`、`en_US.UTF-8` 已生成

### 文档

- 📝 README 澄清：默认 `en_US.UTF-8` 下中文显示正常（UTF-8 编码），locale 语义区别（日期/异常语言）；完整版可 `-e LANG=zh_CN.UTF-8` 切换中文，精简版仅 en_US
- 📝 README 环境变量补 `TZ`、移除 `LC_ALL`，特性列表加时区说明

## [2.1.0] - 2026-06-21

### 重大变更

- 🔄 **放弃 jlink，改打完整 JDK（不再是定制 JRE）**
  - 两个变体（完整版 / 精简版）均改为裁剪后的完整 Eclipse Temurin JDK，保留全部 `java.*`/`jdk.*` 模块与 `javac` 等开发工具
  - 仅删除源码、文档、示例、法律文件、`jmods`、调试符号等非模块内容
  - **解决** jlink 裁剪模块导致的运行期 `NoClassDefFoundError`（如缺 `java.net.http`/`java.desktop`/`java.scripting`/`jdk.zipfs`）
  - Arthas 依赖的 `jdk.attach`/`jdk.jdi`/`jdk.compiler` 在完整 JDK 中天然存在
  - 代价：精简版体积由 ~120MB 升至 ~190-210MB（换取零缺模块异常）

### 新增

- ✨ **多架构构建支持**
  - CI 单次 buildx 构建 `linux/amd64`、`linux/arm64`、`linux/arm`(armv7)，产出多架构 manifest list
  - Dockerfile 用 BuildKit `TARGETARCH` 映射到 Adoptium 架构名（x64/aarch64/arm），按架构自动获取对应下载直链与 SHA256
  - arm64/arm 走 QEMU 仿真构建

### 修复

- 🐛 **彻底移除脆弱的下载 URL 手工拼接**
  - 改用 Adoptium API 的 `binary.package.link` 直链与 `binary.package.checksum` 校验和
  - 顺带消灭 Java 8 URL 双 `b` bug（原 `jdk${...}-b${BUILD}` 与 `BUILD=b08` 拼出 `bb08`）
- 🐛 每个架构各自校验 SHA256（校验和按架构不同），供应链完整性覆盖多架构

### 变更

- 📝 build.sh 简化：按宿主架构取直链+校验和传入，不再手工拼 URL，不再传 `JAVA_UPDATE`/`JAVA_BUILD`
- 📝 CI matrix 精简：仅携带版本号，直链/校验和交给 Dockerfile 按架构取
- 📝 README/TOOLS/AGENTS 全面同步新架构（去 jlink 描述、更新体积估算、build-arg 表、多架构说明）

## [2.0.2] - 2026-06-21

### 修复

- 🐛 修复 Arthas 安装路径不一致问题
  - `arthas-bin.zip` 为平铺结构，原 `unzip -d /opt/` 散落至 `/opt/` 顶层，`ENV PATH` 中的 `/opt/arthas/bin` 并不存在
  - 改为解压到独立目录 `/opt/arthas/`，`PATH` 同步改为 `/opt/arthas`，并 `chmod +x as.sh`
  - 新增 `RUN test -f /opt/arthas/arthas-boot.jar` 构建期校验
  - TOOLS.md 统一为 `/opt/arthas/arthas-boot.jar`
- 🐛 启用 JDK 下载 SHA256 校验（供应链安全）
  - build.sh 从 Adoptium API `binary.package.checksum` 取值并传入 `JAVA_SHA256`
  - CI workflow 同样取值经 matrix 传入，Dockerfile 内 `sha256sum -c` 不再恒跳过
- 🐛 修复 build.sh 失败分支死代码
  - `set -e` 下 `docker build` 失败会直接退出，`if [ $? -eq 0 ]` 的 else 走不到
  - 改为 `if docker build ...; then` 包裹
- 🐛 修复 OCI 标签语义错误
  - `org.opencontainers.image.url` 由 `https://github.com/adoptium` 改为 Docker Hub 镜像页
- 🐛 修复 CI `BUILD_DATE` 语义错误
  - 由 `github.event.repository.updated_at`（仓库元数据更新时间）改为 `date -u` 真实构建时间
- 🐛 移除 CI 多余的 `packages: write` 权限（仅推 Docker Hub，不推 GHCR）

### 文档

- 📝 README 项目结构同步实际文件（移除已删除的 USAGE.md/FIXES.md/JAVA8_OPTIMIZATION.md/test-version-parsing.sh，补充 AGENTS.md/CLAUDE.md/LICENSE）
- 📝 README 补充架构限制说明（当前仅 linux/amd64）与环境变量 PATH 说明
- 📝 README 模块清单补全 `java.instrument`，版本号表格标注"示例，以 Docker Hub 为准"
- 📝 TOOLS.md 删除未安装工具（wget/telnet/net-tools/nano/htop/tcpdump/strace/smem/sysstat/dnsutils），去掉重复表格
- 📝 新增 AGENTS.md（AI 助手项目上下文）与 CLAUDE.md（指向 AGENTS.md）
- 📝 .dockerignore 清理已删除的 `Dockerfile.termurin-*` 规则

## [2.0.1] - 2026-01-12

### 修复

- 🐛 修复 Adoptium API 版本解析逻辑
  - API 响应结构变更: `version_data` → `version`
  - 修复 Java 8 下载 URL 构建
  - 修复 macOS grep 不支持 `-P` 选项的问题
  - 添加版本解析测试脚本
- 🐛 修复 GitHub Actions 输出格式问题
  - 将 JSON 压缩为单行避免多行输出错误
  - 简化工作流，移除冗余的 set-matrix 步骤
- 🐛 修复 JDK 开发工具缺失问题
  - 在 jlink 模块列表中添加 `jdk.compiler` (javac)
  - 添加其他 JDK 工具模块: jdk.jdeps, jdk.jartool, jdk.javadoc, jdk.jlink
  - 确保镜像包含完整的 Java 开发工具链
- 🐛 修复 Java 25 构建失败问题
  - API 默认返回 debugimage 而非标准 JDK
  - 添加过滤参数: `image_type=jdk&os=linux&architecture=x64`
  - 确保获取正确的可用于 jlink 的 JDK 版本
- 🐛 修复 JDK 8/24 jlink 兼容性
  - 通过检测 jmods 目录存在与否决定是否使用 jlink
  - 自动降级到手动精简模式

### 新增

- ✨ 添加开发调试工具包
  - **Arthas**: Java 诊断神器（方法监控、反编译、线程分析）
  - **网络工具**: net-tools, tcpdump, telnet, dnsutils
  - **系统调试**: procps, htop, lsof, strace, smem, sysstat
  - **编辑工具**: vim, nano, less, jq
  - 详细使用说明见 [TOOLS.md](TOOLS.md)

### 优化

- ⚡ 优化 Java 8 镜像大小
  - 删除源代码 (src.zip, javafx-src.zip)
  - 删除示例代码 (demo, sample)
  - 删除开发工具 (Mission Control, VisualVM)
  - 删除 C 头文件 (include) 和调试符号
  - 删除不需要的组件 (Derby DB, JavaFX, Web Start)
  - 预计减小约 50-80MB

### 变更

- 📝 更新 README 中的版本示例为当前最新版本
  - Java 8: 8u472b08
  - Java 17: 17.0.17_10
  - Java 21: 21.0.9_10
  - Java 25: 25.0.1_8

## [2.0.0] - 2026-01-12

### 重大变更

- 🔄 **自动版本检测**: 不再硬编码版本号，从 Adoptium API 自动获取最新版本
- 🏷️ **镜像名变更**: `ofyann-jdk` → `ofyann/java`
- 🏗️ **支持版本调整**: 8, 11, 17, 21 → 8, 17, 21, 25
- 📦 **标签策略**: 同时保留大版本标签（如 `17`）和具体版本标签（如 `17.0.15_6`）

### 新增功能

- ✨ GitHub Actions 每日自动检查新版本并构建
- ✨ 增量构建：仅构建新版本，避免重复
- ✨ 时区支持：默认 `Asia/Shanghai`，可通过 `TIMEZONE` 参数自定义
- ✨ 本地构建自动获取最新版本（需要 jq 和 curl）

### 优化改进

- 🎯 精简项目文件，仅保留构建相关
- 📝 完善 README，增加限制说明和常见问题
- 🔧 更新 build.sh 支持自动版本获取
- 🛠️ 优化 Makefile 命令

### 删除

- ❌ 删除示例目录（examples/）
- ❌ 删除贡献指南（CONTRIBUTING.md）
- ❌ 删除快速开始（QUICKSTART.md）
- ❌ 删除项目总结（PROJECT_SUMMARY.md）
- ❌ 删除 issue 模板
- ❌ 删除旧的 workflow 文件

### 迁移指南

如果你使用的是旧版本镜像：

```bash
# 旧镜像名
FROM ofyann-jdk:17-latest

# 新镜像名
FROM ofyann/java:17
```

### 文件变更

**保留的文件：**
- `Dockerfile` - 主构建文件
- `build.sh` - 本地构建脚本
- `Makefile` - Make 命令
- `README.md` - 项目文档
- `.github/workflows/docker-build.yml` - GitHub Actions 工作流
- `.dockerignore` - Docker 忽略文件
- `.gitignore` - Git 忽略文件

**不再提交的文件：**
- `versions.json` - 动态生成，不提交到版本控制

## [1.0.0] - 之前

初始版本，包含基础的 JDK Docker 镜像构建。
