# OfYann Docker Java - 单 Dockerfile 双变体
#
# 构建目标（build target）：
#   --target minimal  精简版：完整 JDK（仅运行时），无 Arthas/编辑器/中文 locale
#   --target full     完整版：继承 minimal，叠加 Arthas + vim/jq 等工具 + zh_CN locale
#
# 默认 target 为 full（不指定 --target 时构建到最后一个阶段）。

# =============================================================================
# 阶段1: 获取并裁剪完整 JDK（两个变体共享）
# 不再使用 jlink 生成定制 JRE：保留全部 java.* / jdk.* 模块与开发工具（javac 等），
# 仅删除源码/文档/示例/法律文件/调试符号等非模块内容，避免运行期缺模块异常。
# =============================================================================
FROM debian:stable-slim AS jdk-builder

# TARGETARCH 由 BuildKit/buildx 自动注入（amd64/arm64/arm）；本地 docker build 默认为宿主架构
ARG TARGETARCH=amd64
ARG JAVA_MAJOR=17
# 可选：直接指定下载 URL 与校验和；留空则按 TARGETARCH 从 Adoptium API 自动获取（多架构构建用）
ARG JAVA_URL=
ARG JAVA_SHA256=

# 安装构建依赖（jq 用于解析 Adoptium API；本阶段产物不会进入最终镜像）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        binutils \
        jq && \
    rm -rf /var/lib/apt/lists/*

# 解析目标架构 → Adoptium 架构名；必要时从 API 获取下载链接与 SHA256；下载并校验完整性
RUN set -eux; \
    case "$TARGETARCH" in \
        amd64) ADOPT_ARCH=x64 ;; \
        arm64) ADOPT_ARCH=aarch64 ;; \
        arm)   ADOPT_ARCH=arm ;; \
        *) echo "不支持的架构: TARGETARCH=$TARGETARCH" >&2; exit 1 ;; \
    esac; \
    if [ -z "$JAVA_URL" ] || [ -z "$JAVA_SHA256" ]; then \
        echo "从 Adoptium API 获取 Java $JAVA_MAJOR ($ADOPT_ARCH) 下载信息..."; \
        API_URL="https://api.adoptium.net/v3/assets/latest/${JAVA_MAJOR}/hotspot?image_type=jdk&os=linux&architecture=${ADOPT_ARCH}"; \
        RESPONSE=$(curl -fsSL "$API_URL"); \
        [ -z "$JAVA_URL" ] && JAVA_URL=$(printf '%s' "$RESPONSE" | jq -r '.[0].binary.package.link'); \
        [ -z "$JAVA_SHA256" ] && JAVA_SHA256=$(printf '%s' "$RESPONSE" | jq -r '.[0].binary.package.checksum'); \
    fi; \
    echo "下载: $JAVA_URL"; \
    curl -fsSL -o /tmp/jdk.tar.gz "$JAVA_URL"; \
    printf '%s  /tmp/jdk.tar.gz\n' "$JAVA_SHA256" | sha256sum -c -; \
    mkdir -p /opt/jdk; \
    tar -zxf /tmp/jdk.tar.gz -C /opt/jdk --strip-components=1; \
    rm /tmp/jdk.tar.gz

# 安全裁剪 JDK：删除非模块内容，保留全部模块与开发工具
# 注意：保留 lib/jfr（JFR 配置 default.jfc/profile.jfc，jcmd JFR.start 默认加载，删除会导致 JFR 启动失败）
#       保留 include（JNI 头文件 jni.h 等，支持 javac -h 原生方法编译）
RUN set -eux; \
    rm -rf /opt/jdk/src.zip /opt/jdk/javafx-src.zip /opt/jdk/man /opt/jdk/demo \
           /opt/jdk/sample /opt/jdk/db /opt/jdk/legal \
           /opt/jdk/lib/missioncontrol /opt/jdk/lib/visualvm /opt/jdk/lib/src.zip \
           /opt/jdk/jmods; \
    # Java 8 专有的 JavaFX / Web Start（高版本无此路径，自动忽略）
    rm -rf /opt/jdk/jre/lib/plugin.jar /opt/jdk/jre/lib/ext/jfxrt.jar \
           /opt/jdk/jre/bin/javaws /opt/jdk/jre/lib/javaws.jar /opt/jdk/jre/lib/desktop \
           /opt/jdk/jre/plugin /opt/jdk/jre/lib/deploy* /opt/jdk/jre/lib/*javafx* \
           /opt/jdk/jre/lib/*jfx* /opt/jdk/jre/lib/amd64/libdecora_sse.so \
           /opt/jdk/jre/lib/amd64/libprism_*.so /opt/jdk/jre/lib/amd64/libfxplugins.so \
           /opt/jdk/jre/lib/amd64/libglass.so /opt/jdk/jre/lib/amd64/libgstreamer-lite.so \
           /opt/jdk/jre/lib/amd64/libjavafx*.so /opt/jdk/jre/lib/amd64/libjfx*.so 2>/dev/null || true; \
    find /opt/jdk -name '*.diz' -delete 2>/dev/null || true; \
    find /opt/jdk -name '*.debuginfo' -delete 2>/dev/null || true; \
    /opt/jdk/bin/java -version

# =============================================================================
# 阶段2 (target=minimal): 精简运行时镜像
# 完整 JDK + 基础网络/调试工具，无 Arthas/编辑器/中文 locale
# =============================================================================
FROM debian:stable-slim AS minimal

# 元数据标签和配置参数
ARG JAVA_VERSION=17
ARG BUILD_DATE
ARG VCS_REF
ARG TIMEZONE=Asia/Shanghai
ARG TINI_VERSION=v0.19.0

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="OfYann" \
      org.opencontainers.image.url="https://hub.docker.com/r/ofyann/java" \
      org.opencontainers.image.source="https://github.com/ofyann/ofyann-docker-java" \
      org.opencontainers.image.version="${JAVA_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="OfYann JDK Minimal" \
      org.opencontainers.image.description="Eclipse Temurin JDK ${JAVA_VERSION} (minimal) Runtime on Debian Stable Slim"

# 从构建阶段复制裁剪后的完整 JDK
COPY --from=jdk-builder /opt/jdk /opt/java

# 安装运行时依赖和 tini
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        tzdata \
        ca-certificates \
        locales \
        fontconfig \
        curl \
        # 基础网络诊断工具
        iproute2 \
        iputils-ping \
        # 系统调试工具
        procps \
        lsof \
        && \
    # 配置时区（可通过构建参数自定义）
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    # 配置语言环境（仅支持英文，减小体积）
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    # 下载 tini（按容器架构选择）
    ARCH="$(dpkg --print-architecture)" && \
    case "${ARCH}" in \
        amd64) TINI_ARCH='amd64' ;; \
        arm64) TINI_ARCH='arm64' ;; \
        armhf) TINI_ARCH='armhf' ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL -o /usr/bin/tini "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TINI_ARCH}" && \
    chmod +x /usr/bin/tini && \
    # 清理缓存
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置环境变量
# - LANG: en_US.UTF-8（UTF-8 编码确保中文正常显示）；精简版仅生成 en_US，不生成 zh_CN 以减体积
# - TZ: 显式设置时区（与 /etc/localtime 一致），跨 JDK 版本可靠兜底 +8 时区
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    JAVA_HOME=/opt/java \
    TZ=${TIMEZONE} \
    PATH=/opt/java/bin:$PATH

# 验证 Java 安装与时区/locale 配置
RUN set -e; \
    java -version; javac -version; \
    # 确认 locale 已生成（否则 LANG 会回退为 C，导致中文输出乱码）
    # 注：Debian glibc 的 locale -a 输出小写 utf8（en_US.utf8），用 grep -i 忽略大小写以兼容
    locale -a | grep -qi '^en_US\.utf'; \
    # 确认时区文件就位
    test -f /usr/share/zoneinfo/${TZ}; \
    echo "OK locale=LANG=$(locale 2>/dev/null | sed -n 's/^LANG=//p') tz=${TZ}"

# 使用 tini 作为初始化进程
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["java", "-version"]

# =============================================================================
# 阶段3 (target=full): 完整版镜像
# 继承 minimal，叠加 Arthas + 开发工具 + 中文 locale
# =============================================================================
FROM minimal AS full

# ARG 需在本阶段重新声明才能在 LABEL/ENV 中引用（ARG 不跨 stage 继承）
ARG JAVA_VERSION=17
ARG ARTHAS_VERSION=4.1.5

LABEL org.opencontainers.image.title="OfYann JDK" \
      org.opencontainers.image.description="Eclipse Temurin JDK ${JAVA_VERSION} (full) on Debian Stable Slim with Chinese support"

# 叠加开发工具、中文 locale 与 Arthas
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # 基础系统工具
        vim \
        less \
        unzip \
        zip \
        # 通用工具
        jq \
        && \
    # 生成中文 locale（完整版支持 -e LANG=zh_CN.UTF-8 切换中文 locale 语义）
    sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    # 下载并安装 Arthas（arthas-bin.zip 为平铺结构，解压到独立目录 /opt/arthas/）
    curl -fsSL -o /tmp/arthas-bin.zip "https://github.com/alibaba/arthas/releases/download/arthas-all-${ARTHAS_VERSION}/arthas-bin.zip" && \
    mkdir -p /opt/arthas && \
    unzip -q /tmp/arthas-bin.zip -d /opt/arthas/ && \
    chmod +x /opt/arthas/as.sh && \
    rm /tmp/arthas-bin.zip && \
    # 清理缓存
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 覆盖 PATH：加入 Arthas 目录
ENV PATH=/opt/java/bin:/opt/arthas:$PATH

# 验证 Arthas 安装与中文 locale 生成
RUN set -e; \
    test -f /opt/arthas/arthas-boot.jar; \
    locale -a | grep -qi '^zh_CN\.utf'; \
    echo "OK arthas=/opt/arthas/arthas-boot.jar zh_CN=generated"

# ENTRYPOINT/CMD 继承自 minimal（tini + java -version）
