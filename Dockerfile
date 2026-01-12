# 多阶段构建 - 阶段1: 构建自定义 JDK
FROM debian:stable-slim AS jdk-builder

# 构建参数 - 支持外部传入
ARG JAVA_VERSION=17
ARG JAVA_UPDATE=17.0.15
ARG JAVA_BUILD=6
ARG JAVA_MAJOR=17

# 根据版本动态设置下载 URL (支持 JDK 8, 11, 17, 21)
ARG JAVA_URL
ARG JAVA_SHA256

# 安装构建依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        binutils && \
    rm -rf /var/lib/apt/lists/*

# 下载并验证 JDK
RUN if [ -z "$JAVA_URL" ]; then \
        if [ "$JAVA_MAJOR" = "8" ]; then \
            JAVA_URL="https://github.com/adoptium/temurin${JAVA_MAJOR}-binaries/releases/download/jdk${JAVA_UPDATE//./_}-b${JAVA_BUILD}/OpenJDK${JAVA_MAJOR}U-jdk_x64_linux_hotspot_${JAVA_UPDATE//./_}b${JAVA_BUILD}.tar.gz"; \
        else \
            JAVA_URL="https://github.com/adoptium/temurin${JAVA_MAJOR}-binaries/releases/download/jdk-${JAVA_UPDATE}%2B${JAVA_BUILD}/OpenJDK${JAVA_MAJOR}U-jdk_x64_linux_hotspot_${JAVA_UPDATE//./_}_${JAVA_BUILD}.tar.gz"; \
        fi; \
    fi && \
    echo "Downloading from: $JAVA_URL" && \
    wget -O /tmp/jdk.tar.gz "$JAVA_URL" && \
    if [ -n "$JAVA_SHA256" ]; then \
        echo "$JAVA_SHA256 /tmp/jdk.tar.gz" | sha256sum -c -; \
    fi

# 解压 JDK
RUN mkdir -p /opt/jdk && \
    tar -zxf /tmp/jdk.tar.gz -C /opt/jdk --strip-components=1 && \
    rm /tmp/jdk.tar.gz

# 使用 jlink 创建精简的自定义运行时（仅包含必要模块，大幅减小镜像体积）
# 可以通过 JAVA_MODULES 参数自定义模块
# 包含 JDK 开发工具: jdk.compiler (javac), jdk.jdeps, jdk.jartool (jar) 等
ARG JAVA_MODULES="java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.naming,java.prefs,java.rmi,java.scripting,java.security.jgss,java.security.sasl,java.sql,java.xml,java.xml.crypto,jdk.compiler,jdk.jdeps,jdk.jartool,jdk.javadoc,jdk.jlink,jdk.unsupported,jdk.crypto.ec"

RUN if [ "$JAVA_MAJOR" != "8" ] && [ -d "/opt/jdk/jmods" ]; then \
        echo "Detected JDK with jmods. Using jlink..." && \
        # 注意：JDK 21+ 建议使用 --compress=zip-6 替代 --compress=2，但为了兼容旧版暂保留 2 或做额外判断
        COMPRESS_ARG="--compress=2"; \
        if [ "$JAVA_MAJOR" -ge "21" ]; then COMPRESS_ARG="--compress=zip-6"; fi; \
        /opt/jdk/bin/jlink \
            --add-modules ${JAVA_MODULES} \
            --strip-debug \
            --no-man-pages \
            --no-header-files \
            ${COMPRESS_ARG} \
            --output /opt/jdk-minimal; \
    else \
        echo "No jmods found or JDK 8 detected. Using manual cleanup..." && \
        # 手动精简 (兼容 JDK 8 和无 jmods 的高版本 JDK)
        # 删除源代码和文档
        rm -rf /opt/jdk/src.zip \
               /opt/jdk/javafx-src.zip \
               /opt/jdk/man \
               /opt/jdk/demo \
               /opt/jdk/sample \
               /opt/jdk/include \
               /opt/jdk/db \
               /opt/jdk/lib/missioncontrol \
               /opt/jdk/lib/visualvm; \
        # 删除 JavaFX 和 Web Start (主要针对 JDK 8，高版本若不存在这些路径命令也不会报错)
        rm -rf /opt/jdk/jre/lib/plugin.jar \
               /opt/jdk/jre/lib/ext/jfxrt.jar \
               /opt/jdk/jre/bin/javaws \
               /opt/jdk/jre/lib/javaws.jar \
               /opt/jdk/jre/lib/desktop \
               /opt/jdk/jre/plugin \
               /opt/jdk/jre/lib/deploy* \
               /opt/jdk/jre/lib/*javafx* \
               /opt/jdk/jre/lib/*jfx* \
               /opt/jdk/jre/lib/amd64/libdecora_sse.so \
               /opt/jdk/jre/lib/amd64/libprism_*.so \
               /opt/jdk/jre/lib/amd64/libfxplugins.so \
               /opt/jdk/jre/lib/amd64/libglass.so \
               /opt/jdk/jre/lib/amd64/libgstreamer-lite.so \
               /opt/jdk/jre/lib/amd64/libjavafx*.so \
               /opt/jdk/jre/lib/amd64/libjfx*.so 2>/dev/null || true; \
        # 删除调试符号
        find /opt/jdk -name '*.diz' -delete 2>/dev/null || true; \
        # 移动处理后的目录
        mv /opt/jdk /opt/jdk-minimal; \
    fi

# 多阶段构建 - 阶段2: 最终运行镜像
FROM debian:stable-slim

# 元数据标签和配置参数
ARG JAVA_VERSION=17
ARG BUILD_DATE
ARG VCS_REF
ARG TIMEZONE=Asia/Shanghai

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="OfYann" \
      org.opencontainers.image.url="https://github.com/adoptium" \
      org.opencontainers.image.source="https://github.com/ofyann/ofyann-docker-java" \
      org.opencontainers.image.version="${JAVA_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="OfYann JDK" \
      org.opencontainers.image.description="Eclipse Temurin JDK ${JAVA_VERSION} on Debian Stable Slim with Chinese support"

# 从构建阶段复制精简的 JDK
COPY --from=jdk-builder /opt/jdk-minimal /opt/java

# 安装运行时依赖和 tini
ARG TINI_VERSION=v0.19.0
ARG TIMEZONE=Asia/Shanghai
ARG ARTHAS_VERSION=3.7.2
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        tzdata \
        ca-certificates \
        locales \
        fontconfig \
        libx11-6 \
        libxext6 \
        libxrender1 \
        libxi6 \
        libxtst6 \
        curl \
        wget \
        # 基础系统工具
        vim \
        nano \
        less \
        unzip \
        zip \
        # 网络工具包
        net-tools \
        iproute2 \
        iputils-ping \
        dnsutils \
        tcpdump \
        telnet \
        # 系统调试工具
        procps \
        lsof \
        strace \
        htop \
        smem \
        sysstat \
        # 通用工具
        jq \
        vim-tiny \
        && \
    # 配置时区（可通过构建参数自定义）
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    # 配置语言环境（支持中文和英文）
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    # 下载 tini
    ARCH="$(dpkg --print-architecture)" && \
    case "${ARCH}" in \
        amd64) TINI_ARCH='amd64' ;; \
        arm64) TINI_ARCH='arm64' ;; \
        armhf) TINI_ARCH='armhf' ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    wget -O /usr/bin/tini "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TINI_ARCH}" && \
    chmod +x /usr/bin/tini && \
    # 下载并安装 Arthas
    wget -O /tmp/arthas-bin.zip "https://github.com/alibaba/arthas/releases/download/${ARTHAS_VERSION}/arthas-bin.zip" && \
    unzip -q /tmp/arthas-bin.zip -d /opt/ && \
    rm /tmp/arthas-bin.zip && \
    # 清理缓存
    apt-get purge -y wget && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置环境变量
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    JAVA_HOME=/opt/java \
    PATH=/opt/java/bin:/opt/arthas/bin:$PATH

# 验证 Java 安装
RUN java -version && javac -version

# 使用 tini 作为初始化进程
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["java", "-version"]
