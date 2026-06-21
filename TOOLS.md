# 开发调试工具

本镜像（完整版，`--target full`）包含常用的开发调试工具。精简版（`--target minimal`）仅含运行时，不含下列大部分工具。

## 工具列表

### Java 诊断
| 工具 | 说明 |
|------|------|
| Arthas | Java 诊断神器：方法监控、反编译、线程分析 |

### 网络工具
| 工具 | 说明 |
|------|------|
| curl | HTTP / 下载工具 |
| iproute2 | `ip`、`ss` 网络配置与诊断 |
| iputils-ping | `ping` 连通性测试 |

### 系统工具
| 工具 | 说明 |
|------|------|
| vim | 文本编辑 |
| less | 文件查看 |
| jq | JSON 处理 |
| unzip / zip | 压缩 / 解压 |
| lsof | 查看打开的文件 |
| procps | `ps`、`top`、`free`、`vmstat` |

> 说明：`wget`、`telnet`、`net-tools`、`nano`、`htop`、`tcpdump`、`strace`、`smem`、`sysstat`、`dnsutils` 等未安装。如需可自行 `apt-get install` 或在 Dockerfile 中扩展。

## Arthas 常用命令

Arthas 安装在 `/opt/arthas/`，已加入 `PATH`。

```bash
# 启动诊断（任选其一）
java -jar /opt/arthas/arthas-boot.jar
as.sh                         # /opt/arthas/as.sh

# 查看仪表盘
dashboard

# 线程分析
thread -n 5          # Top 5 CPU 线程
thread -b            # 阻塞线程

# 方法监控
trace com.example.App doMethod
watch com.example.App doMethod params returnObj

# 反编译
jad com.example.App

# 内存分析
heapdump /tmp/dump.hprof
```

## 常用示例

```bash
# 网络测试
curl -v http://api:8080/health

# 进程排查
ps aux | grep java
lsof -p $(pgrep java)

# 日志查看
tail -f /app/logs/app.log
```

## 环境变量

```bash
JAVA_HOME=/opt/java
PATH=/opt/java/bin:/opt/arthas:$PATH
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
TZ=Asia/Shanghai  # 默认时区
```

## 工具路径

- Java: `/opt/java/bin/`
- Arthas: `/opt/arthas/`（`arthas-boot.jar`、`as.sh` 等）
- 系统工具: `/usr/bin/`
