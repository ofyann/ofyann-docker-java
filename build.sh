#!/bin/bash

# Docker 镜像构建脚本
# 支持构建不同版本的 JDK 镜像（完整版和精简版）
#
# 使用方法:
#   ./build.sh [JAVA_VERSION] [IMAGE_TAG]
#
# 环境变量:
#   BUILD_VARIANT - 构建版本类型: full (完整版), minimal (精简版), both (两者，默认)
#   NO_CACHE      - 是否禁用缓存: true/false (默认 false)
#   TIMEZONE      - 时区设置 (默认 Asia/Shanghai)
#
# 示例:
#   ./build.sh 17                           # 构建 Java 17 两个版本
#   BUILD_VARIANT=full ./build.sh 17        # 只构建完整版
#   BUILD_VARIANT=minimal ./build.sh 17     # 只构建精简版
#   NO_CACHE=true ./build.sh 17             # 无缓存构建两个版本
#
# 说明:
#   本脚本按宿主架构从 Adoptium API 获取下载直链与 SHA256，作为 build-arg 传入
#   （Dockerfile 收到后会跳过自身的 API 请求）。多架构构建请通过 CI 的
#   docker buildx 多平台构建完成（Dockerfile 会按 TARGETARCH 自行取链）。
#   完整版与精简版由同一 Dockerfile 的不同 build target（full / minimal）实现。

set -e

# 默认值
# DISTRO: JDK 发行版（temurin/zulu/corretto/liberica...），影响默认镜像标签前缀
# 注：当前 Dockerfile 仅实现了 temurin 的下载逻辑；其他发行版需在 jdk-builder 阶段按 DISTRO 切换源
DISTRO=${DISTRO:-temurin}
JAVA_VERSION=${1:-17}
# 默认标签遵循命名规则 ofyann/java:<distro>-<version>[-<variant>]
IMAGE_TAG=${2:-"ofyann/java:${DISTRO}-${JAVA_VERSION}"}
BUILD_VARIANT=${BUILD_VARIANT:-both}  # full, minimal, both
NO_CACHE=${NO_CACHE:-false}
TIMEZONE=${TIMEZONE:-Asia/Shanghai}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 宿主架构 → Adoptium 架构名
detect_adopt_arch() {
    case "$(uname -m)" in
        x86_64)         echo "x64" ;;
        aarch64|arm64)  echo "aarch64" ;;
        armv7l|armhf)   echo "arm" ;;
        *) print_error "不支持的宿主架构: $(uname -m)"; return 1 ;;
    esac
}

# 验证 Java 版本：先校验为纯数字（拒绝含空格/特殊字符的输入），再校验在支持列表内
SUPPORTED_VERSIONS="8 17 21 25"
case "$JAVA_VERSION" in
    ''|*[!0-9]*)
        print_error "非法的 Java 版本: ${JAVA_VERSION}（必须为纯数字）"
        print_info "支持的版本: $SUPPORTED_VERSIONS"
        exit 1
        ;;
esac
case " $SUPPORTED_VERSIONS " in
    *" $JAVA_VERSION "*) : ;;
    *)
        print_error "不支持的 Java 版本: ${JAVA_VERSION}"
        print_info "支持的版本: $SUPPORTED_VERSIONS"
        exit 1
        ;;
esac

# 自动获取最新版本（直链、SHA256、版本号），全部直接取自 Adoptium API，无需手工拼 URL
fetch_version() {
    local version=$1
    local adopt_arch
    adopt_arch=$(detect_adopt_arch) || return 1

    print_info "正在获取 Java $version ($adopt_arch) 的最新版本..."

    local api_url="https://api.adoptium.net/v3/assets/latest/${version}/hotspot?image_type=jdk&os=linux&architecture=${adopt_arch}"
    local response
    response=$(curl -fsSL "$api_url" 2>/dev/null) || {
        print_error "无法从 API 获取 Java $version 版本信息"
        return 1
    }

    if [ -z "$response" ] || [ "$response" = "[]" ]; then
        print_error "无法从 API 获取 Java $version 版本信息"
        return 1
    fi

    OPENJDK_VERSION=$(printf '%s' "$response" | jq -r '.[0].version.openjdk_version')
    SEMVER=$(printf '%s' "$response" | jq -r '.[0].version.semver // empty')
    JAVA_URL=$(printf '%s' "$response" | jq -r '.[0].binary.package.link')
    JAVA_SHA256=$(printf '%s' "$response" | jq -r '.[0].binary.package.checksum')

    if [ -z "$JAVA_URL" ] || [ "$JAVA_URL" = "null" ] || [ -z "$JAVA_SHA256" ] || [ "$JAVA_SHA256" = "null" ]; then
        print_error "无法解析下载链接或校验和"
        return 1
    fi

    print_info "  最新版本: $OPENJDK_VERSION"

    # 解析具体版本标签（仅用于日志展示；直接取结构化字段，避免脆弱的 sed 正则）
    if [ "$version" = "8" ]; then
        # Java 8: openjdk_version "1.8.0_492-b09" -> 8u492b09
        local security build
        security=$(printf '%s' "$OPENJDK_VERSION" | sed -n 's/.*_\([0-9]*\).*/\1/p')
        build=$(printf '%s' "$OPENJDK_VERSION" | sed -n 's/.*-\(b[0-9]*\).*/\1/p')
        [ -n "$security" ] && [ -n "$build" ] && FULL_VERSION="8u${security}${build}"
    else
        # Java 11+: 优先用结构化 version.security/build 字段，回退到 semver 解析
        local major minor security build
        major=$(printf '%s' "$response" | jq -r '.[0].version.major // empty')
        minor=$(printf '%s' "$response" | jq -r '.[0].version.minor // empty')
        security=$(printf '%s' "$response" | jq -r '.[0].version.security // empty')
        build=$(printf '%s' "$response" | jq -r '.[0].version.build // empty')
        if [ -n "$major" ] && [ -n "$security" ] && [ -n "$build" ]; then
            if [ "$minor" = "0" ] || [ -z "$minor" ]; then
                FULL_VERSION="${major}.0.${security}_${build}"
            else
                FULL_VERSION="${major}.${minor}.${security}_${build}"
            fi
        else
            # 回退：semver "17.0.19+10" 或 "21.0.9+10.0.LTS" -> 17.0.19_10
            local clean_semver update
            clean_semver=$(printf '%s' "$SEMVER" | sed 's/\.0\.LTS$//' | sed 's/-LTS$//')
            update=$(printf '%s' "$clean_semver" | sed -n 's/^\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
            build=$(printf '%s' "$clean_semver" | sed -n 's/.*+\([0-9]*\).*/\1/p')
            [ -n "$update" ] && [ -n "$build" ] && FULL_VERSION="${update}_${build}"
        fi
    fi

    return 0
}

# 尝试自动获取版本
if ! fetch_version "$JAVA_VERSION"; then
    print_error "无法自动获取版本信息"
    print_info "请确保已安装 jq 和 curl"
    exit 1
fi

print_info "======================================"
print_info "  JDK Docker 镜像构建"
print_info "======================================"
print_info "Java 版本: ${JAVA_VERSION}"
print_info "具体版本: ${FULL_VERSION:-未知}"
print_info "架构: $(detect_adopt_arch)"
print_info "镜像标签: ${IMAGE_TAG}"
print_info "下载 URL: ${JAVA_URL}"
print_info "======================================"

# 构建参数
BUILD_ARGS=(
    --build-arg "JAVA_MAJOR=${JAVA_VERSION}"
    --build-arg "JAVA_VERSION=${JAVA_VERSION}"
    --build-arg "JAVA_URL=${JAVA_URL}"
    --build-arg "JAVA_SHA256=${JAVA_SHA256}"
    --build-arg "TIMEZONE=${TIMEZONE}"
    --build-arg "BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    --build-arg "VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
)

# 添加 no-cache 选项
if [ "$NO_CACHE" = "true" ]; then
    BUILD_ARGS+=(--no-cache)
fi

# 构建镜像的函数
# 参数: variant(full|minimal) tag description
build_image() {
    local variant=$1
    local tag=$2
    local description=$3

    print_info "======================================"
    print_info "  构建 ${description}"
    print_info "======================================"
    print_info "Dockerfile: Dockerfile (target=${variant})"
    print_info "镜像标签: ${tag}"
    print_info ""

    # 构建镜像（用 if 包裹，避免 set -e 直接退出导致失败分支成为死代码）
    print_info "开始构建镜像..."
    if docker build \
        --target "${variant}" \
        "${BUILD_ARGS[@]}" \
        -t "${tag}" \
        -f Dockerfile \
        . ; then
        print_info "✓ ${description} 构建成功！"
        print_info ""
        print_info "测试镜像..."
        # 测试门：java/javac 验证失败则视为构建失败（显式处理，因 set -e 在 if 上下文被挂起）
        if ! docker run --rm "${tag}" java -version; then
            print_error "镜像验证失败: java -version 异常"
            return 1
        fi
        docker run --rm "${tag}" javac -version 2>/dev/null || print_warn "javac 不可用"

        print_info ""
        print_info "镜像信息:"
        docker images "${tag}" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
        print_info ""
        print_info "运行容器:"
        print_info "  docker run -it --rm ${tag} bash"
        print_info ""
        return 0
    else
        print_error "${description} 构建失败！"
        return 1
    fi
}

# 根据 BUILD_VARIANT 构建镜像
if [ "$BUILD_VARIANT" = "full" ] || [ "$BUILD_VARIANT" = "both" ]; then
    print_info "======================================"
    print_info "  构建完整版（带 Arthas）"
    print_info "======================================"
    FULL_TAG="${IMAGE_TAG}"
    if ! build_image "full" "${FULL_TAG}" "完整版（带 Arthas 和开发工具）"; then
        exit 1
    fi
fi

if [ "$BUILD_VARIANT" = "minimal" ] || [ "$BUILD_VARIANT" = "both" ]; then
    print_info "======================================"
    print_info "  构建精简版（纯运行时）"
    print_info "======================================"
    # 生成精简版标签：已含 -minimal 后缀直接用；否则在版本部分追加 -minimal
    if [[ "${IMAGE_TAG}" == *"-minimal" ]]; then
        MINIMAL_TAG="${IMAGE_TAG}"
    elif [[ "${IMAGE_TAG}" == *:* ]]; then
        # 含冒号：repo:tag -> repo:tag-minimal
        MINIMAL_TAG="${IMAGE_TAG}-minimal"
    else
        # 无冒号的自定义标签：追加 :latest-minimal
        MINIMAL_TAG="${IMAGE_TAG}:latest-minimal"
    fi

    if ! build_image "minimal" "${MINIMAL_TAG}" "精简版（纯运行时）"; then
        exit 1
    fi
fi

# 显示所有构建的镜像
print_info "======================================"
print_info "  构建完成"
print_info "======================================"
if [ "$BUILD_VARIANT" = "both" ]; then
    print_info "已构建两个版本的镜像:"
    print_info "  完整版: ${FULL_TAG}"
    print_info "  精简版: ${MINIMAL_TAG}"
elif [ "$BUILD_VARIANT" = "full" ]; then
    print_info "已构建完整版镜像: ${FULL_TAG}"
elif [ "$BUILD_VARIANT" = "minimal" ]; then
    print_info "已构建精简版镜像: ${MINIMAL_TAG}"
fi
print_info "======================================"
