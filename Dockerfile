FROM node:lts-alpine

WORKDIR /opt/app

# 安装必要的依赖包
RUN apk add --no-cache curl tzdata unzip bash

ENV TIME_ZONE=Asia/Shanghai
RUN cp /usr/share/zoneinfo/$TIME_ZONE /etc/localtime && echo $TIME_ZONE > /etc/timezone

# 下载 Sub-Store 及前端资源
ADD https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js /opt/app/sub-store.bundle.js
ADD https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip /opt/app/dist.zip

RUN unzip -q dist.zip && mv dist frontend && rm -f dist.zip

# 创建 http-meta 目录并下载脚本和配置
RUN mkdir -p /opt/app/http-meta
ADD https://github.com/xream/http-meta/releases/latest/download/http-meta.bundle.js /opt/app/http-meta.bundle.js
ADD https://github.com/xream/http-meta/releases/latest/download/tpl.yaml /opt/app/http-meta/tpl.yaml

# 下载 mihomo 内核并重命名赋予执行权限
RUN set -ex && \
    version=$(curl -s -L --connect-timeout 5 --max-time 15 --retry 3 'https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt') && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64) mihomo_arch="amd64-compatible" ;; \
      aarch64|arm64) mihomo_arch="arm64" ;; \
      *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    url="https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-linux-$mihomo_arch-$version.gz" && \
    curl -s -L --connect-timeout 5 --max-time 30 --retry 3 "$url" -o /opt/app/http-meta/mihomo.gz && \
    gzip -d /opt/app/http-meta/mihomo.gz && \
    mv /opt/app/http-meta/mihomo /opt/app/http-meta/http-meta && \
    chmod +x /opt/app/http-meta/http-meta

RUN chmod -R 777 /opt/app

# 仅对外暴露 3001（前端服务端口）
EXPOSE 3001

# 启动配置：
# 1. http-meta 只监听回环地址 127.0.0.1，避免被平台的端口扫描探针误判为主 Web 进程
# 2. sub-store 作为主进程监听 0.0.0.0:3001 对外提供健康检查与 Web 服务
CMD mkdir -p /opt/app/data && cd /opt/app/data && \
    META_FOLDER=/opt/app/http-meta HOST=127.0.0.1 node /opt/app/http-meta.bundle.js & \
    SUB_STORE_BACKEND_API_HOST=0.0.0.0 \
    SUB_STORE_FRONTEND_HOST=0.0.0.0 \
    SUB_STORE_FRONTEND_PORT=3001 \
    SUB_STORE_BACKEND_API_PORT=3000 \
    SUB_STORE_DATA_BASE_PATH=/opt/app/data \
    SUB_STORE_FRONTEND_PATH=/opt/app/frontend \
    exec node /opt/app/sub-store.bundle.js
