#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

find_ppa_root() {
  local candidate

  for candidate in \
    "${PPA_HOME:-}" \
    "$ROOT_DIR/Tazama/payment-platform-adapter" \
    "$ROOT_DIR/payment-platform-adapter"
  do
    [ -n "$candidate" ] || continue
    if [ -d "$candidate" ] && [ -f "$candidate/package.json" ]; then
      PPA_HOME="$candidate"
      export PPA_HOME
      return 0
    fi
  done

  echo "Unable to find payment-platform-adapter. Set PPA_HOME or clone it under $ROOT_DIR/Tazama/payment-platform-adapter." >&2
  exit 1
}

load_tazama_env() {
  local env_file="${TAZAMA_ENV_FILE:-$CONF_DIR/tazama.env}"

  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

load_ppa_env() {
  local env_file="${PPA_ENV_FILE:-$CONF_DIR/ppa.env}"

  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi

  export PPA_ENV_FILE="$env_file"
}

normalize_ppa_defaults() {
  TMS_PORT="${TMS_PORT:-5000}"

  PPA_HOST="${PPA_HOST:-127.0.0.1}"
  PPA_PORT="${PPA_PORT:-3500}"

  FUNCTION_NAME="${FUNCTION_NAME:-payment_platform_adapter}"
  NODE_ENV="${NODE_ENV:-dev}"

  KAFKA_URI="${KAFKA_URI:-127.0.0.1:9092}"
  KAFKA_CLIENT_ID="${KAFKA_CLIENT_ID:-mojaloop-local-ppa}"
  KAFKA_CONSUMER_GROUP="${KAFKA_CONSUMER_GROUP:-mojaloop-local-ppa}"
  KAFKA_TOPIC_TO_CONSUME="${KAFKA_TOPIC_TO_CONSUME:-topic-quotes-post}"

  REDIS_URL="${REDIS_URL:-127.0.0.1}"
  REDIS_PORT="${REDIS_PORT:-6379}"

  TMS_BASE_URL="${TMS_BASE_URL:-http://127.0.0.1:${TMS_PORT}}"
  TMS_ENDPOINT="${TMS_ENDPOINT:-$TMS_BASE_URL}"
  TMS_PAIN001_ENDPOINT="${TMS_PAIN001_ENDPOINT:-$TMS_BASE_URL/v1/evaluate/iso20022/pain.001.001.13}"
  TMS_PAIN013_ENDPOINT="${TMS_PAIN013_ENDPOINT:-$TMS_BASE_URL/v1/evaluate/iso20022/pain.013.001.09}"
  TMS_PACS008_ENDPOINT="${TMS_PACS008_ENDPOINT:-$TMS_BASE_URL/v1/evaluate/iso20022/pacs.008.001.10}"
  TMS_PACS002_ENDPOINT="${TMS_PACS002_ENDPOINT:-$TMS_BASE_URL/v1/evaluate/iso20022/pacs.002.001.12}"

  PPA_PID_FILE="$RUN_DIR/ppa.pid"
  PPA_LOG_FILE="$LOG_DIR/ppa.log"
  PPA_ENTRYPOINT="$PPA_HOME/build/index.js"

  export TMS_PORT
  export PPA_HOST PPA_PORT
  export FUNCTION_NAME NODE_ENV
  export KAFKA_URI KAFKA_CLIENT_ID KAFKA_CONSUMER_GROUP KAFKA_TOPIC_TO_CONSUME
  export REDIS_URL REDIS_PORT
  export TMS_BASE_URL TMS_ENDPOINT TMS_PAIN001_ENDPOINT TMS_PAIN013_ENDPOINT TMS_PACS008_ENDPOINT TMS_PACS002_ENDPOINT
  export PPA_PID_FILE PPA_LOG_FILE PPA_ENTRYPOINT
}

ensure_ppa_dependencies() {
  if [ ! -d "$PPA_HOME/node_modules" ]; then
    echo "Missing payment-platform-adapter/node_modules. Run local/scripts/npm-ci-ppa.sh first." >&2
    exit 1
  fi
}

print_ppa_summary() {
  echo "PPA root: $PPA_HOME"
  echo "PPA env file: $PPA_ENV_FILE"
  echo "PPA URL: http://${PPA_HOST}:${PPA_PORT}"
  echo "Kafka topic: $KAFKA_TOPIC_TO_CONSUME"
  echo "TMS base URL: $TMS_BASE_URL"
  echo "Redis: ${REDIS_URL}:${REDIS_PORT}"
}

ppa_init() {
  load_tazama_env
  load_ppa_env
  find_ppa_root
  normalize_ppa_defaults
}
