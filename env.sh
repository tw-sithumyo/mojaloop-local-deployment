#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_ROOT="$ROOT_DIR/runtime-root"
NODE_HOME="$ROOT_DIR/tools/node-v22.22.0-linux-x64"
JAVA_HOME="$ROOT_DIR/tools/jdk-21.0.10+7-jre"
KAFKA_HOME="$ROOT_DIR/tools/kafka_2.13-3.9.1"
LOCAL_HOME="$ROOT_DIR/local"
DATA_DIR="$LOCAL_HOME/data"
LOG_DIR="$LOCAL_HOME/logs"
RUN_DIR="$LOCAL_HOME/run"
CONF_DIR="$LOCAL_HOME/config"

export ROOT_DIR RUNTIME_ROOT NODE_HOME JAVA_HOME KAFKA_HOME LOCAL_HOME DATA_DIR LOG_DIR RUN_DIR CONF_DIR
export PATH="$NODE_HOME/bin:$JAVA_HOME/bin:$RUNTIME_ROOT/usr/bin:$KAFKA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$RUNTIME_ROOT/usr/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="$RUNTIME_ROOT/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export NPM_CONFIG_UPDATE_NOTIFIER=false
export NPM_CONFIG_FUND=false
export npm_config_update_notifier=false
export npm_config_fund=false

mkdir -p "$DATA_DIR" "$LOG_DIR" "$RUN_DIR" "$CONF_DIR"
