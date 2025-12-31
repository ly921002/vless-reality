FROM alpine:latest

RUN apk add --no-cache \
  bash curl unzip openssl iproute2 ca-certificates

WORKDIR /app

# 下载 xray（构建期）
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64) XRAY_ARCH=64 ;; \
      aarch64|arm64) XRAY_ARCH=arm64-v8a ;; \
      *) exit 1 ;; \
    esac && \
    curl -L -o /tmp/xray.zip \
      "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XRAY_ARCH}.zip" && \
    unzip /tmp/xray.zip xray -d /app && \
    chmod +x /app/xray && \
    rm -f /tmp/xray.zip
    
COPY init.sh entrypoint.sh /app/
RUN chmod +x /app/*.sh

EXPOSE 443/tcp

ENTRYPOINT ["/app/entrypoint.sh"]
