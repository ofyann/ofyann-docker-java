# 更新日志

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
