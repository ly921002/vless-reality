FROM alpine:latest

RUN apk add --no-cache \
  bash curl unzip openssl iproute2 ca-certificates

WORKDIR /app

COPY init.sh entrypoint.sh /app/
RUN chmod +x /app/*.sh

EXPOSE 443/tcp

ENTRYPOINT ["/app/entrypoint.sh"]
