#!/usr/bin/env bash
set -e

##################################
# 参数（可通过 docker-compose 覆盖）
##################################
PORT=${PORT:-443}
DOMAIN=${DOMAIN:-apple.com}
NODE_NAME=${NODE_NAME:-vl-reality}

BASE_DIR="/app"
CONF_DIR="$BASE_DIR/conf"
CONF_FILE="$CONF_DIR/config.json"
XRAY_BIN="$BASE_DIR/xray"

mkdir -p "$CONF_DIR"

##################################
# IPv6 探测
##################################
HAS_IPV6=0
if ip -6 route get 2001:4860:4860::8888 >/dev/null 2>&1; then
  HAS_IPV6=1
fi

LISTEN_ADDR="0.0.0.0"
[ "$HAS_IPV6" -eq 1 ] && LISTEN_ADDR="::"

##################################
# 下载 xray（目录内）
##################################
if [ ! -f "$XRAY_BIN" ]; then
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) XRAY_ARCH="64" ;;
    aarch64|arm64) XRAY_ARCH="arm64-v8a" ;;
    *) echo "不支持架构"; exit 1 ;;
  esac

  curl -L -o /tmp/xray.zip \
    "https://download.lycn.qzz.io/xray-linux-${XRAY_ARCH}"
  unzip /tmp/xray.zip xray -d /tmp
  mv /tmp/xray "$XRAY_BIN"
  chmod +x "$XRAY_BIN"
fi

##################################
# UUID
##################################
[ -f "$CONF_DIR/uuid" ] || "$XRAY_BIN" uuid > "$CONF_DIR/uuid"
UUID=$(cat "$CONF_DIR/uuid")

##################################
# Reality Key
##################################
if [ ! -f "$CONF_DIR/private.key" ]; then
  KP=$("$XRAY_BIN" x25519)
  echo "$KP" | awk '/PrivateKey/ {print $2}' > "$CONF_DIR/private.key"
  echo "$KP" | awk '/Password/ {print $2}' > "$CONF_DIR/public.key"
fi
PRIVATE_KEY=$(cat "$CONF_DIR/private.key")
PUBLIC_KEY=$(cat "$CONF_DIR/public.key")

##################################
# Short ID
##################################
[ -f "$CONF_DIR/short_id" ] || openssl rand -hex 4 > "$CONF_DIR/short_id"
SHORT_ID=$(cat "$CONF_DIR/short_id")

##################################
# 生成 config.json
##################################
cat > "$CONF_FILE" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "$LISTEN_ADDR",
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "$UUID", "flow": "xtls-rprx-vision" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "fingerprint": "chrome",
          "dest": "$DOMAIN:443",
          "serverNames": ["$DOMAIN"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

##################################
# 输出分享链接（自动 IP）
##################################
SERVER_IP=""
[ "$HAS_IPV6" -eq 1 ] && SERVER_IP=$(curl -6 -s https://api64.ipify.org)
[ -z "$SERVER_IP" ] && SERVER_IP=$(curl -4 -s https://api.ipify.org)

echo
echo "========= VLESS Reality ========="
echo "监听地址: $LISTEN_ADDR"
echo "端口: $PORT"
echo
echo "vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#${NODE_NAME}"
echo "================================"
