#!/usr/bin/env sh
set -eu

if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

if [ -n "${BASH_VERSION:-}" ]; then
  LOCAL_ENV_SOURCE="${BASH_SOURCE}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  LOCAL_ENV_SOURCE="$(eval 'printf "%s" "${(%):-%x}"')"
elif [ -f "./local/env.sh" ]; then
  LOCAL_ENV_SOURCE="./local/env.sh"
elif [ -f "./env.sh" ]; then
  LOCAL_ENV_SOURCE="./env.sh"
else
  LOCAL_ENV_SOURCE="$0"
fi

ROOT_DIR="$(cd "$(dirname "$LOCAL_ENV_SOURCE")/.." && pwd)"
PIVOTAL_HOME="${PIVOTAL_HOME:-$ROOT_DIR/pivotal-new}"
PIVOTAL_CONNECTOR_HOME="${PIVOTAL_CONNECTOR_HOME:-$ROOT_DIR/pivotal-connector-nestjs}"
DEMOWALLET_HOME="${DEMOWALLET_HOME:-$ROOT_DIR/Mojaloop-DemoWallet}"
OPERATION_PORTAL_HOME="${OPERATION_PORTAL_HOME:-$ROOT_DIR/ml-operation-portal}"
RUNTIME_ROOT="$ROOT_DIR/runtime-root"
NODE_HOME="$ROOT_DIR/tools/node-v22.22.0-linux-x64"
JDK11_HOME="$ROOT_DIR/tools/jdk-11.0.27+6"
JDK_HOME="$ROOT_DIR/tools/jdk-21.0.10+7"
JAVA_HOME="$ROOT_DIR/tools/jdk-21.0.10+7-jre"
DEMOWALLET_JAVA_HOME="${DEMOWALLET_JAVA_HOME:-$JDK11_HOME}"
MAVEN_HOME="$ROOT_DIR/tools/apache-maven-3.9.10"
KAFKA_HOME="$ROOT_DIR/tools/kafka_2.13-3.9.1"
LOCAL_HOME="$ROOT_DIR/local"
DATA_DIR="$LOCAL_HOME/data"
LOG_DIR="$LOCAL_HOME/logs"
RUN_DIR="$LOCAL_HOME/run"
CONF_DIR="$LOCAL_HOME/config"

export ROOT_DIR PIVOTAL_HOME PIVOTAL_CONNECTOR_HOME DEMOWALLET_HOME OPERATION_PORTAL_HOME RUNTIME_ROOT NODE_HOME JDK11_HOME JDK_HOME JAVA_HOME DEMOWALLET_JAVA_HOME MAVEN_HOME KAFKA_HOME LOCAL_HOME DATA_DIR LOG_DIR RUN_DIR CONF_DIR
export PATH="$NODE_HOME/bin:$JAVA_HOME/bin:$MAVEN_HOME/bin:$RUNTIME_ROOT/usr/bin:$KAFKA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$RUNTIME_ROOT/usr/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="$RUNTIME_ROOT/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export NPM_CONFIG_UPDATE_NOTIFIER=false
export NPM_CONFIG_FUND=false
export NPM_CONFIG_CACHE="$DATA_DIR/npm-cache"
export npm_config_update_notifier=false
export npm_config_fund=false
export npm_config_cache="$DATA_DIR/npm-cache"

mkdir -p "$DATA_DIR" "$DATA_DIR/npm-cache" "$LOG_DIR" "$RUN_DIR" "$CONF_DIR"
