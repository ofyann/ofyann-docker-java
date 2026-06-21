# AGENTS.md

> 本文件为 AI 助手提供项目上下文。请保持简洁，只写入跨任务通用的关键信息。
> 局部模块细节请写在对应子目录的 AGENTS.md 中，自动叠加。

---

## 1. 项目速览

- **名称**: ofyann-docker-java
- **一句话描述**: 自动构建的 Eclipse Temurin JDK Docker 镜像，提供完整版（带 Arthas 诊断工具）与精简版（纯运行时）两种变体，均为**完整 JDK**（保留全部模块，不再用 jlink），支持 Java 8 / 17 / 21 / 25，多架构（amd64/arm64/armv7），每日自动检测新版本并构建。
- **技术栈**: Dockerfile（多阶段构建）+ Debian stable-slim 基础镜像 + 完整 Temurin JDK（手工安全裁剪，非 jlink）+ GitHub Actions（matrix + buildx 多平台）+ Bash 构建脚本 + Makefile
- **目标环境**: Linux 容器运行时（Docker / Kubernetes），CI 产出 `linux/amd64`、`linux/arm64`、`linux/arm`(armv7) 多架构 manifest。

---

## 2. 目录结构速查

```text
ofyann-docker-java/
├── Dockerfile                 # 单 Dockerfile 三阶段：jdk-builder → minimal → full（双变体由 build target 切换）
├── build.sh                   # 本地构建脚本：从 Adoptium API 自动获取版本号，调用 docker build
├── Makefile                   # 封装 build/test/push/clean/inspect 等常用命令
├── .github/workflows/
│   └── docker-build.yml       # CI：每日 UTC 00:00 + push main + 手动触发；matrix 同时构建 4 版本 × 2 变体
├── README.md                  # 面向使用者的完整文档（注意：部分章节已与实现不同步，见下）
├── TOOLS.md                   # 镜像内工具说明（注意：列出的部分工具实际未安装）
├── CHANGELOG.md               # 更新日志
├── LICENSE                    # MIT
├── .dockerignore              # 构建上下文忽略规则
└── .gitignore                 # 忽略 versions.json 等动态产物
```

> 注：README "项目结构" 一节列出的 `USAGE.md`、`FIXES.md`、`JAVA8_OPTIMIZATION.md`、`test-version-parsing.sh` 已在重构中删除，文档未同步——修改时请以本节为准。

---

## 3. 构建与发布

### 本地构建

```bash
./build.sh 17                     # 构建 Java 17，自动获取最新版本（完整版 + 精简版）
BUILD_VARIANT=minimal ./build.sh 17   # 只构建精简版
NO_CACHE=true ./build.sh 17           # 无缓存
TIMEZONE=America/New_York ./build.sh 17
make build JAVA_VERSION=17        # 等价于 ./build.sh
make test JAVA_VERSION=17         # 运行 java -version / javac -version 验证
```

**前置依赖**：Docker 20.10+、`jq`、`curl`（build.sh 用 jq 解析 Adoptium API 响应）。

### 关键构建参数（build-arg）

| 参数 | 说明 | 谁负责传入 |
|------|------|-----------|
| `JAVA_MAJOR` | 大版本号 8/17/21/25 | build.sh + workflow |
| `JAVA_URL` | 可选：完整下载直链。传入则 Dockerfile 跳过 API 请求 | build.sh 传（宿主架构）；CI 不传（让 Dockerfile 按架构取） |
| `JAVA_SHA256` | 可选：对应架构的 SHA256。传入则直接校验 | build.sh 传；CI 不传 |
| `TIMEZONE` | 默认 `Asia/Shanghai` | 两者皆可覆盖 |
| `BUILD_DATE` / `VCS_REF` | OCI 标签 | build.sh 用 `date -u`；CI 用单独 step 生成 |

> **架构解析**：Dockerfile 用 BuildKit 的 `TARGETARCH`（amd64/arm64/arm）映射到 Adoptium 架构名（x64/aarch64/arm）。当 `JAVA_URL`/`JAVA_SHA256` 任一为空时，按 `TARGETARCH` 从 Adoptium API 取 `binary.package.link` + `binary.package.checksum`。这使单次 buildx 多平台构建能为每个平台取到正确的直链与校验和。

### CI 发布流程

1. `fetch-versions` job：对 8/17/21/25 调 Adoptium API（x64），解析版本号生成 matrix（每版本 × full/minimal）。**仅取版本号**，直链/校验和留给 Dockerfile 按架构取。
2. `build-and-push` job：用 buildx 构建，`target` 为 `full`/`minimal`（单 Dockerfile）。策略按事件分：
   - **push 到 main**：仅 `linux/amd64`、`push=false`、`load=true`——快速验证代码改动，不耗 QEMU、不污染镜像仓库。
   - **schedule（每周一）/ workflow_dispatch**：`linux/amd64,linux/arm64,linux/arm` 全架构、`push=true`。先 `docker manifest inspect` 判断具体版本标签是否存在，存在则跳过（`force_build` 可强制）。
   - 双标签：`ofyann/java:<major>[-minimal]` + `ofyann/java:<full_version>[-minimal]`。
3. 测试仅跑 amd64（arm 依赖 QEMU 仿真，较慢，只验证构建成功）。
4. `report` job：写 `GITHUB_STEP_SUMMARY`。

**所需 Secrets**：`DOCKERHUB_USERNAME`、`DOCKERHUB_TOKEN`。

> **成本控制**：每周一次全量多架构构建（4 版本 × 2 变体 × 3 架构，arm 走 QEMU 较慢）。push 仅 amd64 验证避免额度浪费。免费额度 2000min/月下，若仍紧张可考虑：arm 仅在新版本时构建、或改用 `eclipse-temurin` 官方 arm 镜像避免 QEMU。

---

## 4. 版本解析逻辑（最易出错，改动需谨慎）

`build.sh` 的 `fetch_version()` 与 workflow 的 fetch 步骤逻辑需保持一致：

- **下载直链/校验和**：直接取 Adoptium API 的 `binary.package.link` 与 `binary.package.checksum`（按架构），无需手工拼 URL。
- **Java 8 版本号**：`openjdk_version` 形如 `1.8.0_492-b09` → sed 拆 `8u492` + `b09` → `8u492b09`。
- **Java 11+ 版本号**：build.sh 优先用结构化字段 `version.major/minor/security/build`（最稳），回退到 semver 解析（需 `sed` 去 `.LTS`/`-LTS` 后缀）。workflow fetch 阶段仍用 semver + sed（仅打标签用）。

**注意**：解析失败时 workflow 仅 `continue` 跳过该版本，不会让 CI 失败——排查"某版本镜像没更新"时优先看 fetch 阶段日志。

---

## 5. 单 Dockerfile 双 target 架构

同一 `Dockerfile` 三个阶段：`jdk-builder`（共享，获取并裁剪完整 JDK）→ `minimal`（精简最终阶段）→ `full`（继承 minimal，叠加 Arthas/工具/zh_CN）。用 `--target` 切换：

| 维度 | 完整版 (`--target full`) | 精简版 (`--target minimal`) |
|------|--------------------|-----------------------------|
| JDK | 完整 JDK（全部模块 + javac） | 完整 JDK（全部模块 + javac） |
| Arthas | ✅ `/opt/arthas/` | ❌ |
| 系统工具 | vim/less/unzip/zip/jq + 网络诊断 | 仅 curl + 网络诊断 |
| 中文 locale | ✅ zh_CN.UTF-8（可 `-e LANG=zh_CN.UTF-8` 切换） | ❌ 仅 en_US.UTF-8 |
| 标签后缀 | 无（`ofyann/java:temurin-17`） | `-minimal`（`ofyann/java:temurin-17-minimal`） |

> 关键设计：**不再使用 jlink**。两个变体都是裁剪后的完整 JDK，仅删除非模块内容（src/man/demo/legal/jmods/调试符号；保留 lib/jfr 与 include）。这避免了 jlink 裁剪模块导致的运行期 `NoClassDefFoundError`（如缺 `java.net.http`/`java.desktop`/`java.scripting`/`jdk.zipfs`）。Arthas 依赖的 `jdk.attach`/`jdk.jdi`/`jdk.compiler` 在完整 JDK 中天然存在。
>
> 单 Dockerfile 设计消除双份维护漂移风险：full 继承 minimal，仅叠加差异层，改 JDK 裁剪逻辑只需改一处。

---

## 6. 镜像命名规则（所有镜像必须遵守）

单仓库 `ofyann/java`，用**标签前缀**区分发行版，避免多发行版撞车。**不使用 `ofyann/java:17` 这类无发行版前缀的别名**——所有标签必须明确标注发行版，杜绝歧义。

### 核心格式

```
ofyann/java:<distro>-<version>[-<variant>]
```

| 维度 | 说明 | 取值 |
|------|------|------|
| `<distro>` | JDK 发行版，小写，必填 | `temurin`（Eclipse Temurin，当前唯一）、`zulu`、`corretto`、`liberica`、`dragonwell`、`graalvm` 等 |
| `<version>` | Java 大版本，必填 | `8` / `17` / `21` / `25`（滚动标签）；具体小版本如 `17.0.19_10`、`8u492b09`（固定标签） |
| `<variant>` | 变体后缀，可选，省略=完整版 | 完整版无后缀；`-minimal`（纯运行时）。未来可扩展 `-alpine`、`-jre` 等 |

维度顺序固定为 **distro-version-variant**（架构不进标签）。

### 标签类型（每个构建产物打两套）

1. **滚动标签**（大版本最新，随版本更新移动）：
   ```
   ofyann/java:temurin-17              # 完整版，Java 17 最新
   ofyann/java:temurin-17-minimal      # 精简版，Java 17 最新
   ```
2. **固定标签**（具体小版本，永不移动，用于版本锁定）：
   ```
   ofyann/java:temurin-17.0.19_10          # 完整版，17.0.19+10
   ofyann/java:temurin-17.0.19_10-minimal  # 精简版
   ofyann/java:temurin-8u492b09            # Java 8 完整版
   ```

### 架构

**架构不进标签**。通过多架构 manifest list 实现，`docker pull` 自动选择匹配宿主架构（amd64/arm64/arm）。如需调试显式拉取某架构，用 `docker pull --platform linux/arm64 ofyann/java:temurin-17`。

### 完整示例矩阵

| 含义 | 标签 |
|------|------|
| Temurin Java 17 完整版（最新） | `ofyann/java:temurin-17` |
| Temurin Java 17 精简版（最新） | `ofyann/java:temurin-17-minimal` |
| Temurin Java 17 完整版（锁定 17.0.19+10） | `ofyann/java:temurin-17.0.19_10` |
| Temurin Java 8 完整版（最新） | `ofyann/java:temurin-8` |
| Temurin Java 8 完整版（锁定 8u492b09） | `ofyann/java:temurin-8u492b09` |
| 未来 Zulu Java 21 完整版 | `ofyann/java:zulu-21` |
| 未来 Corretto Java 17 精简版 | `ofyann/java:corretto-17-minimal` |

### 作为基础镜像

```dockerfile
# 生产：精简版（体积小）
FROM ofyann/java:temurin-17-minimal
COPY app.jar /app/app.jar
CMD ["java", "-jar", "/app/app.jar"]

# 开发/调试：完整版（带 Arthas）
FROM ofyann/java:temurin-17
```

### 向后兼容与迁移（重要）

本仓库早期使用过无发行版前缀的旧标签：

| 旧标签（已弃用） | 新标签（当前） |
|------------------|----------------|
| `ofyann/java:17` | `ofyann/java:temurin-17` |
| `ofyann/java:17-minimal` | `ofyann/java:temurin-17-minimal` |
| `ofyann/java:17.0.17_10` | `ofyann/java:temurin-17.0.17_10` |
| `ofyann/java:8` | `ofyann/java:temurin-8` |

- **决策**：不保留旧标签作为别名（避免双份维护与歧义）。CI 切换到新命名后停止产生旧标签。
- **现有用户**：旧镜像已在 Docker Hub 上，仍可拉取（不会删除），但不再更新。请在 `FROM` 中迁移到新标签。
- 早期 README/CHANGELOG 中的 `ofyann/java:17` 等示例仅为历史记录，以本节规则为准。

### 扩展新发行版的步骤

1. 在 `build.sh` 与 workflow 的 `JAVA_VERSIONS` 循环中，为该发行版增加取版本逻辑（Adoptium API 仅服务 Temurin；Zulu/Corretto 等需各自的 API 或硬编码版本）。
2. Dockerfile 的 `jdk-builder` 阶段按 `DISTRO` build-arg 切换下载源（直链优先，回退各发行版 API）。
3. 标签统一加 `<distro>-` 前缀，无需新建仓库。
4. 更新本节取值表与示例。

### 命名规则约定（改动前必读）

- **任何新标签必须含 `<distro>-` 前缀**，禁止再产生无前缀别名。
- `<distro>` 一律小写，与发行版官方名对齐（Temurin→`temurin`，Zulu→`zulu`，Corretto→`corretto`）。
- 具体版本号格式：Java 8 用 `8u<security>b<build>`（如 `8u492b09`），Java 11+ 用 `<major>.<minor>.<security>_<build>`（如 `17.0.19_10`），与版本解析逻辑一致。
- 变体后缀以 `-` 连接，新增变体（如 `-alpine`）须在本节登记，避免与发行版/版本名混淆。
- 改 CI/build.sh 标签生成时，**滚动标签与固定标签必须成对产生**，二者缺一不可。

---

## 7. 已知问题与约定（改动前必读）

> 已修复（2026-06-21）：
> - Arthas 路径统一到 `/opt/arthas/`；build.sh 与 CI 启用 SHA256 校验；build.sh `set -e` 死代码改为 `if docker build`；OCI `image.url` 改指 Docker Hub；CI `BUILD_DATE` 改用真实构建时间；移除多余 `packages: write` 权限；TOOLS.md/README/.dockerignore 与实现同步。
> - **放弃 jlink，改打完整 JDK**：解决缺模块运行异常，顺带消灭 Java 8 URL 双 `b` bug 与脆弱的 URL 手工拼接（改用 API 直链 `binary.package.link`）。保留 `lib/jfr`（JFR 配置）与 `include`（JNI 头）。
> - **多架构支持**：Dockerfile 按 `TARGETARCH` 自取架构直链+校验和；CI 全量构建 `linux/amd64,linux/arm64,linux/arm`。
> - **本地化与时区**：新增 `ENV TZ` 与 `/etc/localtime` 双重时区设置（跨 JDK 版本兜底 +8）；移除强制 `LC_ALL` 保留 locale 切换能力；构建期校验 locale 已生成 + 时区文件就位；CI 时区/locale 测试加断言。默认 `LANG=en_US.UTF-8`（中文显示正常），完整版保留 `zh_CN.UTF-8` 可 `-e LANG=zh_CN.UTF-8` 切换。
> - **单 Dockerfile 双 target**：合并 `Dockerfile` + `Dockerfile.minimal` 为单文件（`jdk-builder`→`minimal`→`full`），消除双份维护漂移。build.sh 与 CI 改用 `--target` 切换变体。
> - **build.sh 边界 bug**：版本校验改纯数字+列表精确匹配（拒绝 `"8 17"`/`.*` 等注入）；MINIMAL_TAG 处理无冒号标签；构建后测试门加 `|| return 1`（原 `if` 上下文 set -e 挂起致测试失效）；版本解析优先用 jq 结构化字段。
> - **CI 成本控制**：schedule 改每周（避免每日 16×3 QEMU 撑爆额度）；push 事件仅 amd64 验证不推送（`load=true`）。

> 仍待处理（改动时可一并修复）：

1. **arm 架构测试缺失**：CI 仅跑 amd64 运行时测试，arm64/arm 仅验证构建成功。
2. **本地化待容器实测**：开发机为 macOS，无法跑真实 Linux 容器，mac 的 `user.language`/`user.country` 由系统偏好注入会干扰结论。Java 层 locale 与 JDK 8 时区的真实行为需在 CI 构建后或 Linux 容器中复验（CI 已加 `date +%z==+0800` 与 Java `ZonedDateTime` 含 `+08:00` 断言）。
3. **体积优化（用户暂缓）**：jlink 全模块（81MB vs 当前 183MB）+ alpine 基础可大幅瘦身且零缺模块，但用户明确"先不压缩"。如需启用，jlink `--strip-debug` 做成可选 build-arg（默认开瘦身，需异常行号时关），JDK 8 退回手工裁剪。

**约定**：
- 改 JDK 裁剪逻辑只需改单 Dockerfile 的 `jdk-builder` 阶段（full/minimal 共享）。
- 保留完整 JDK：不要为减小体积重新引入 jlink 裁剪模块——会重新引入缺模块运行异常。如需更小体积，优先删非模块内容或换更小基础镜像。
- 改 locale/时区：时区同时设 `ENV TZ` 与 `/etc/localtime`（不要只设其一）；minimal 与 full 的 locale 差异在各自阶段维护。
- 提交信息沿用现有 gitmoji 风格（`:bug:` / `:sparkles:` / `fix:`）。

---

## 8. 常用验证命令

```bash
make test JAVA_VERSION=17                          # 验证 java/javac（默认 DISTRO=temurin）
docker run --rm ofyann/java:temurin-17 java --list-modules   # 查看包含的模块（完整 JDK，全部模块）
docker run --rm ofyann/java:temurin-17 locale | grep -i utf  # 验证 locale
docker run --rm ofyann/java:temurin-17 date +%Z              # 验证时区
curl -s "https://api.adoptium.net/v3/assets/latest/17/hotspot?image_type=jdk&os=linux&architecture=x64" | jq
```
