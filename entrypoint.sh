#!/usr/bin/env bash
set -e
cd /app
exec ./xray run -c conf/config.json
