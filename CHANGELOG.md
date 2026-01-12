# 更新日志

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
