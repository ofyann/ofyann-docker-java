#!/bin/bash

# Docker 镜像构建脚本
# 支持构建不同版本的 JDK 镜像

set -e

# 默认值
JAVA_VERSION=${1:-17}
IMAGE_TAG=${2:-"ofyann/java:${JAVA_VERSION}"}
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

# 自动获取最新版本或使用手动配置
fetch_version() {
    local version=$1
    print_info "正在获取 Java $version 的最新版本..."

    # 从 Adoptium API 获取最新版本（过滤标准 JDK）
    API_URL="https://api.adoptium.net/v3/assets/latest/${version}/hotspot?image_type=jdk&os=linux&architecture=x64"
    RESPONSE=$(curl -s "$API_URL" 2>/dev/null)

    if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "[]" ]; then
        print_error "无法从 API 获取 Java $version 版本信息"
        return 1
    fi

    # 解析版本信息
    VERSION_OBJ=$(echo "$RESPONSE" | jq -r '.[0].version' 2>/dev/null)
    if [ -z "$VERSION_OBJ" ] || [ "$VERSION_OBJ" = "null" ]; then
        print_error "无法解析版本数据"
        return 1
    fi

    SEMVER=$(echo "$VERSION_OBJ" | jq -r '.semver')
    OPENJDK_VERSION=$(echo "$VERSION_OBJ" | jq -r '.openjdk_version')
    print_info "  最新版本: $OPENJDK_VERSION"

    # 根据版本号格式解析
    if [ "$version" = "8" ]; then
        # Java 8: openjdk_version "1.8.0_472-b08" -> 8u472 和 b08
        SECURITY=$(echo "$OPENJDK_VERSION" | sed -n 's/.*_\([0-9]*\).*/\1/p')
        BUILD=$(echo "$OPENJDK_VERSION" | sed -n 's/.*-\(b[0-9]*\).*/\1/p')
        if [ -n "$SECURITY" ] && [ -n "$BUILD" ]; then
            JAVA_CONFIGS[${version}_update]="8u${SECURITY}"
            JAVA_CONFIGS[${version}_build]="$BUILD"
        fi
    else
        # Java 11+: semver "17.0.17+10" 或 "21.0.9+10.0.LTS" -> 17.0.17 和 10
        CLEAN_SEMVER=$(echo "$SEMVER" | sed 's/\.0\.LTS$//' | sed 's/-LTS$//')
        UPDATE=$(echo "$CLEAN_SEMVER" | sed -n 's/^\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
        BUILD=$(echo "$CLEAN_SEMVER" | sed -n 's/.*+\([0-9]*\).*/\1/p')
        if [ -n "$UPDATE" ] && [ -n "$BUILD" ]; then
            JAVA_CONFIGS[${version}_update]="$UPDATE"
            JAVA_CONFIGS[${version}_build]="$BUILD"
        fi
    fi

    return 0
}

# 版本配置
declare -A JAVA_CONFIGS

# 验证 Java 版本
SUPPORTED_VERSIONS="8 17 21 25"
if [[ ! $SUPPORTED_VERSIONS =~ (^|[[:space:]])$JAVA_VERSION($|[[:space:]]) ]]; then
    print_error "不支持的 Java 版本: ${JAVA_VERSION}"
    print_info "支持的版本: $SUPPORTED_VERSIONS"
    exit 1
fi

# 尝试自动获取版本
if ! fetch_version "$JAVA_VERSION"; then
    print_error "无法自动获取版本信息"
    print_info "请确保已安装 jq 和 curl"
    exit 1
fi

# 获取版本信息
JAVA_UPDATE="${JAVA_CONFIGS[${JAVA_VERSION}_update]}"
JAVA_BUILD="${JAVA_CONFIGS[${JAVA_VERSION}_build]}"
JAVA_SHA256="${JAVA_CONFIGS[${JAVA_VERSION}_sha256]}"

# 构建下载 URL
if [ "$JAVA_VERSION" = "8" ]; then
    URL_UPDATE="${JAVA_UPDATE//./_}"
    JAVA_URL="https://github.com/adoptium/temurin${JAVA_VERSION}-binaries/releases/download/jdk${URL_UPDATE}-${JAVA_BUILD}/OpenJDK${JAVA_VERSION}U-jdk_x64_linux_hotspot_${URL_UPDATE}${JAVA_BUILD}.tar.gz"
else
    JAVA_URL="https://github.com/adoptium/temurin${JAVA_VERSION}-binaries/releases/download/jdk-${JAVA_UPDATE}%2B${JAVA_BUILD}/OpenJDK${JAVA_VERSION}U-jdk_x64_linux_hotspot_${JAVA_UPDATE//./_}_${JAVA_BUILD}.tar.gz"
fi

print_info "======================================"
print_info "  JDK Docker 镜像构建"
print_info "======================================"
print_info "Java 版本: ${JAVA_VERSION}"
print_info "Java 更新: ${JAVA_UPDATE}"
print_info "构建号: ${JAVA_BUILD}"
print_info "镜像标签: ${IMAGE_TAG}"
print_info "下载 URL: ${JAVA_URL}"
print_info "======================================"

# 构建参数
BUILD_ARGS=(
    --build-arg "JAVA_MAJOR=${JAVA_VERSION}"
    --build-arg "JAVA_VERSION=${JAVA_VERSION}"
    --build-arg "JAVA_UPDATE=${JAVA_UPDATE}"
    --build-arg "JAVA_BUILD=${JAVA_BUILD}"
    --build-arg "JAVA_URL=${JAVA_URL}"
    --build-arg "JAVA_SHA256=${JAVA_SHA256:-}"
    --build-arg "TIMEZONE=${TIMEZONE}"
    --build-arg "BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    --build-arg "VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
)

# 添加 no-cache 选项
if [ "$NO_CACHE" = "true" ]; then
    BUILD_ARGS+=(--no-cache)
fi

# 构建镜像
print_info "开始构建镜像..."
docker build \
    "${BUILD_ARGS[@]}" \
    -t "${IMAGE_TAG}" \
    -f Dockerfile \
    .

# 验证构建
if [ $? -eq 0 ]; then
    print_info "✓ 镜像构建成功！"
    print_info ""
    print_info "测试镜像..."
    docker run --rm "${IMAGE_TAG}" java -version
    docker run --rm "${IMAGE_TAG}" javac -version
    print_info ""
    print_info "镜像信息:"
    docker images "${IMAGE_TAG}" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    print_info ""
    print_info "运行容器:"
    print_info "  docker run -it --rm ${IMAGE_TAG} bash"
else
    print_error "镜像构建失败！"
    exit 1
fi
