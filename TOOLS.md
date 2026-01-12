# 开发调试工具

本镜像包含丰富的开发调试工具。

## 工具列表

### Java 诊断
| 工具 | 说明 |
|------|------|
| Arthas | Java 诊断神器：方法监控、反编译、线程分析 |

### 网络工具
| 工具 | 说明 |
|------|------|
| curl, wget | HTTP/下载工具 |
| telnet | TCP 连接测试 |
| net-tools | ifconfig, netstat, route |
| iproute2 | ip, ss |
| dnsutils | nslookup, dig |
| tcpdump | 网络抓包 |

### 系统工具
| 工具 | 说明 |
|------|------|
| vim, nano | 文本编辑 |
| jq | JSON 处理 |
| htop, top | 进程监控 |
| lsof | 查看打开的文件 |
| strace | 系统调用追踪 |
| procps | ps, free, vmstat |
| smem, sysstat | 性能分析 |

## Arthas 常用命令

```bash
# 启动诊断
java -jar /opt/arthas-boot.jar

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
telnet db 3306

# 进程排查
ps aux | grep java
lsof -p $(pgrep java)

# 性能分析
htop
iostat -x 1

# 日志查看
tail -f /app/logs/app.log
```

## 环境变量

```bash
JAVA_HOME=/opt/java
PATH=/opt/java/bin:/opt/arthas/bin:$PATH
```

## 工具路径

- Java: `/opt/java/bin/`
- Arthas: `/opt/arthas/bin/`
- 系统工具: `/usr/bin/`
