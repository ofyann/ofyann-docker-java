.PHONY: help build build-all test clean push

# 默认配置
DOCKER_REGISTRY ?= docker.io
IMAGE_NAME ?= ofyann/java
JAVA_VERSION ?= 17
TIMEZONE ?= Asia/Shanghai

# 颜色输出
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help: ## 显示帮助信息
	@echo "$(GREEN)OfYann Docker Java - Makefile 帮助$(NC)"
	@echo ""
	@echo "可用命令:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "示例:"
	@echo "  make build JAVA_VERSION=17        # 构建 Java 17"
	@echo "  make build-all                     # 构建所有版本"
	@echo "  make test JAVA_VERSION=21         # 测试 Java 21"
	@echo "  make push JAVA_VERSION=17         # 推送 Java 17"

build: ## 构建指定版本的镜像 (JAVA_VERSION=17)
	@echo "$(GREEN)构建 Java $(JAVA_VERSION) 镜像...$(NC)"
	@TIMEZONE=$(TIMEZONE) ./build.sh $(JAVA_VERSION) $(IMAGE_NAME):$(JAVA_VERSION)

build-all: ## 构建所有支持的 Java 版本
	@echo "$(GREEN)构建所有 Java 版本...$(NC)"
	@for version in 8 17 21 25; do \
		echo "$(YELLOW)构建 Java $$version...$(NC)"; \
		TIMEZONE=$(TIMEZONE) ./build.sh $$version $(IMAGE_NAME):$$version || exit 1; \
	done
	@echo "$(GREEN)✓ 所有版本构建完成$(NC)"

test: ## 测试指定版本的镜像 (JAVA_VERSION=17)
	@echo "$(GREEN)测试 Java $(JAVA_VERSION) 镜像...$(NC)"
	@docker run --rm $(IMAGE_NAME):$(JAVA_VERSION) java -version
	@docker run --rm $(IMAGE_NAME):$(JAVA_VERSION) javac -version
	@docker run --rm $(IMAGE_NAME):$(JAVA_VERSION) java --list-modules 2>/dev/null || true
	@echo "$(GREEN)✓ 测试通过$(NC)"

test-all: ## 测试所有构建的镜像
	@echo "$(GREEN)测试所有镜像...$(NC)"
	@for version in 8 17 21 25; do \
		echo "$(YELLOW)测试 Java $$version...$(NC)"; \
		docker run --rm $(IMAGE_NAME):$$version java -version || exit 1; \
		docker run --rm $(IMAGE_NAME):$$version javac -version || exit 1; \
	done
	@echo "$(GREEN)✓ 所有测试通过$(NC)"

push: ## 推送指定版本到镜像仓库 (JAVA_VERSION=17)
	@echo "$(GREEN)推送 Java $(JAVA_VERSION) 镜像...$(NC)"
	@docker push $(IMAGE_NAME):$(JAVA_VERSION)
	@echo "$(GREEN)✓ 推送完成$(NC)"

push-all: ## 推送所有版本到镜像仓库
	@echo "$(GREEN)推送所有镜像...$(NC)"
	@for version in 8 17 21 25; do \
		echo "$(YELLOW)推送 Java $$version...$(NC)"; \
		docker push $(IMAGE_NAME):$$version || exit 1; \
	done
	@echo "$(GREEN)✓ 所有镜像已推送$(NC)"

clean: ## 清理本地构建的镜像
	@echo "$(YELLOW)清理本地镜像...$(NC)"
	@docker images | grep $(IMAGE_NAME) | awk '{print $$3}' | xargs -r docker rmi -f || true
	@echo "$(GREEN)✓ 清理完成$(NC)"

inspect: ## 查看指定版本镜像的详细信息 (JAVA_VERSION=17)
	@echo "$(GREEN)镜像信息:$(NC)"
	@docker inspect $(IMAGE_NAME):$(JAVA_VERSION) | jq '.[0] | {Id: .Id, Created: .Created, Size: .Size, Architecture: .Architecture, Os: .Os}'

shell: ## 进入指定版本镜像的交互式 shell (JAVA_VERSION=17)
	@echo "$(GREEN)启动容器 shell...$(NC)"
	@docker run -it --rm $(IMAGE_NAME):$(JAVA_VERSION) bash

size: ## 显示所有镜像的大小
	@echo "$(GREEN)镜像大小:$(NC)"
	@docker images | grep $(IMAGE_NAME) | awk '{printf "%-40s %-15s\n", $$1":"$$2, $$7" "$$8}'

login: ## 登录 Docker Registry
	@echo "$(GREEN)登录到 $(DOCKER_REGISTRY)...$(NC)"
	@docker login $(DOCKER_REGISTRY)

# 高级功能
build-no-cache: ## 无缓存构建指定版本 (JAVA_VERSION=17)
	@echo "$(GREEN)无缓存构建 Java $(JAVA_VERSION)...$(NC)"
	@NO_CACHE=true TIMEZONE=$(TIMEZONE) ./build.sh $(JAVA_VERSION) $(IMAGE_NAME):$(JAVA_VERSION)

tag-latest: ## 将指定版本标记为 latest (JAVA_VERSION=17)
	@echo "$(GREEN)标记 Java $(JAVA_VERSION) 为 latest...$(NC)"
	@docker tag $(IMAGE_NAME):$(JAVA_VERSION) $(IMAGE_NAME):latest
	@echo "$(GREEN)✓ 标记完成$(NC)"

# 默认目标
.DEFAULT_GOAL := help
