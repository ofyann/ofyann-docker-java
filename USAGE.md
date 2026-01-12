# 使用示例

## 快速开始

### 拉取并使用镜像

```bash
# 拉取镜像
docker pull ofyann/java:17

# 查看版本
docker run --rm ofyann/java:17 java -version

# 编译代码
docker run --rm -v "$PWD":/work -w /work ofyann/java:17 javac Main.java

# 运行程序
docker run --rm -v "$PWD":/work -w /work ofyann/java:17 java Main
```

## 本地构建

### 基础构建

```bash
# 构建 Java 17（自动获取最新版本）
./build.sh 17

# 查看帮助
make help

# 使用 Makefile
make build JAVA_VERSION=17
```

### 自定义构建

```bash
# 自定义时区
TIMEZONE=America/New_York ./build.sh 17

# 无缓存构建
NO_CACHE=true ./build.sh 17

# 指定镜像名
./build.sh 17 myorg/java:17
```

## 作为基础镜像

### 简单应用

```dockerfile
FROM ofyann/java:17

WORKDIR /app
COPY target/app.jar .

CMD ["java", "-jar", "app.jar"]
```

### Spring Boot 应用

```dockerfile
FROM ofyann/java:17

WORKDIR /app
COPY target/*.jar app.jar

EXPOSE 8080

ENV JAVA_OPTS="-Xmx512m -Xms256m"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

### 多阶段构建

```dockerfile
# 构建阶段
FROM ofyann/java:17 AS builder

WORKDIR /build
COPY . .
RUN ./gradlew build

# 运行阶段
FROM ofyann/java:17

WORKDIR /app
COPY --from=builder /build/build/libs/*.jar app.jar

CMD ["java", "-jar", "app.jar"]
```

## GitHub Actions

### 配置 Secrets

在仓库设置中添加：

1. `DOCKERHUB_USERNAME` - Docker Hub 用户名
2. `DOCKERHUB_TOKEN` - Docker Hub 访问令牌

### 自动触发

推送代码到 main 分支会自动触发构建：

```bash
git add .
git commit -m "Update Dockerfile"
git push origin main
```

### 手动触发

1. 访问 GitHub Actions 页面
2. 选择 "Docker Build and Push"
3. 点击 "Run workflow"
4. 选择是否强制构建

## 常用命令

### Docker 命令

```bash
# 拉取镜像
docker pull ofyann/java:17

# 运行容器
docker run -it --rm ofyann/java:17 bash

# 查看镜像信息
docker inspect ofyann/java:17

# 查看镜像大小
docker images ofyann/java

# 删除镜像
docker rmi ofyann/java:17
```

### Make 命令

```bash
# 构建
make build JAVA_VERSION=17

# 构建所有版本
make build-all

# 测试
make test JAVA_VERSION=17

# 推送
make push JAVA_VERSION=17

# 清理
make clean

# 查看大小
make size

# 进入 shell
make shell JAVA_VERSION=17
```

## 时区配置

### 构建时设置

```bash
# 使用环境变量
TIMEZONE=America/New_York ./build.sh 17

# 使用构建参数
docker build \
  --build-arg TIMEZONE=America/New_York \
  -t ofyann/java:17 \
  .
```

### 运行时设置

```bash
# 使用环境变量
docker run -e TZ=America/New_York ofyann/java:17 date

# 映射宿主机时区
docker run -v /etc/localtime:/etc/localtime:ro ofyann/java:17 date

# 在 Dockerfile 中设置
ENV TZ=America/New_York
```

## JVM 优化

### 内存配置

```bash
# 设置堆内存
docker run -e JAVA_OPTS="-Xmx512m -Xms256m" ofyann/java:17 java $JAVA_OPTS -jar app.jar

# 使用容器内存百分比（Java 10+）
docker run -e JAVA_OPTS="-XX:MaxRAMPercentage=75.0" ofyann/java:17 java $JAVA_OPTS -jar app.jar
```

### GC 优化

```bash
# 使用 G1GC
JAVA_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# 使用 ZGC (Java 15+)
JAVA_OPTS="-XX:+UseZGC"

# 开启 GC 日志
JAVA_OPTS="-Xlog:gc*:file=/tmp/gc.log:time,uptime:filecount=5,filesize=10M"
```

## 故障排查

### 检查 API 可用性

```bash
# 测试 Adoptium API
curl -s "https://api.adoptium.net/v3/assets/latest/17/hotspot" | jq

# 查看可用版本
for v in 8 17 21 25; do
  echo "Java $v:"
  curl -s "https://api.adoptium.net/v3/assets/latest/$v/hotspot" | jq -r '.[0].version_data.semver'
done
```

### 构建失败

```bash
# 检查依赖
which jq
which curl

# 测试网络
curl -I https://github.com

# 查看构建日志
docker build --progress=plain -t test .
```

### 镜像问题

```bash
# 验证镜像
docker run --rm ofyann/java:17 java -version
docker run --rm ofyann/java:17 javac -version

# 检查时区
docker run --rm ofyann/java:17 date
docker run --rm ofyann/java:17 cat /etc/timezone

# 检查 locale
docker run --rm ofyann/java:17 locale

# 检查模块（Java 9+）
docker run --rm ofyann/java:17 java --list-modules
```

## 最佳实践

### 1. 使用具体版本标签

```dockerfile
# 推荐：使用具体版本
FROM ofyann/java:17.0.15_6

# 不推荐：使用浮动版本
FROM ofyann/java:17
```

### 2. 多阶段构建

分离构建和运行环境，减小最终镜像大小。

### 3. 非 root 用户

```dockerfile
FROM ofyann/java:17

RUN useradd -r -u 1000 appuser
USER appuser

CMD ["java", "-jar", "app.jar"]
```

### 4. 健康检查

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1
```

### 5. 资源限制

```bash
docker run -m 512m --cpus=1 ofyann/java:17 java -jar app.jar
```

## 更多信息

查看 [README.md](README.md) 获取完整文档。
