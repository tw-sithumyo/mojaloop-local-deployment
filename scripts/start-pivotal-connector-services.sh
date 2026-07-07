#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
source "$LOCAL_HOME/scripts/print-local-endpoints.sh"

TARGET="${1:-all}"

if [ ! -f "$PIVOTAL_CONNECTOR_HOME/package.json" ]; then
  echo "Missing pivotal connector repo: $PIVOTAL_CONNECTOR_HOME/package.json" >&2
  exit 1
fi

if [ ! -d "$PIVOTAL_CONNECTOR_HOME/node_modules" ]; then
  "$LOCAL_HOME/scripts/npm-ci-pivotal-connector.sh"
fi

if [ ! -f "$PIVOTAL_CONNECTOR_HOME/dist/main.js" ]; then
  rm -f "$PIVOTAL_CONNECTOR_HOME/tsconfig.tsbuildinfo"
  (
    cd "$PIVOTAL_CONNECTOR_HOME"
    npm run build
  )
fi

start_connector() {
  local wallet="$1"
  local env_file="$CONF_DIR/${wallet}-pivotal.env"
  local default_backend_url="$2"
  local name="${wallet}-pivotal-connector"
  local log_file="$LOG_DIR/$name.log"
  local pid_file="$RUN_DIR/$name.pid"
  local pattern="pivotal-connector-nestjs-${wallet}"

  if [ ! -f "$env_file" ]; then
    echo "Missing $wallet env file: $env_file" >&2
    exit 1
  fi

  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    return
  fi

  if pgrep -af "$pattern" >/dev/null 2>&1; then
    pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$pid_file" || true
    return
  fi

  set -a
  source "$env_file"
  set +a

  local backend_api_url="${BACKEND_API_URL:-${DEMOWALLET_URL:-$default_backend_url}}"
  local redis_url="${PIVOTAL_CONNECTOR_REDIS_URL:-redis://127.0.0.1:6379}"
  local redis_ttl_seconds="${PIVOTAL_CONNECTOR_REDIS_TTL_SECONDS:-1200}"
  local backend_timeout_ms="${BACKEND_API_TIMEOUT_MS:-30000}"
  local backend_fee_percentage="${BACKEND_API_FEE_PERCENTAGE:-1}"
  local fspiop_stream_name="${PIVOTAL_FSPIOP_STREAM_NAME:-PIVOTAL_FSPIOP}"

  : >"$log_file"

  (
    cd "$PIVOTAL_CONNECTOR_HOME"
    setsid -f env \
      NODE_ENV=production \
      CONNECTOR_ID="$CONNECTOR_ID" \
      CONNECTOR_SUPPORTED_CURRENCIES="$CONNECTOR_SUPPORTED_CURRENCIES" \
      CONNECTOR_ILP_SECRET="$CONNECTOR_ILP_SECRET" \
      NATS_URL="$NATS_URL" \
      FSPIOP_STREAM_NAME="$fspiop_stream_name" \
      FSPIOP_PARTIES_URL="$FSPIOP_PARTIES_URL" \
      FSPIOP_QUOTES_URL="$FSPIOP_QUOTES_URL" \
      FSPIOP_TRANSFERS_URL="$FSPIOP_TRANSFERS_URL" \
      FSPIOP_SWITCH_ID="$FSPIOP_SWITCH_ID" \
      REDIS_URL="$redis_url" \
      REDIS_TTL_SECONDS="$redis_ttl_seconds" \
      BACKEND_API_URL="$backend_api_url" \
      BACKEND_API_TIMEOUT_MS="$backend_timeout_ms" \
      BACKEND_API_FEE_PERCENTAGE="$backend_fee_percentage" \
      bash -c 'exec -a "$0" "$@"' "pivotal-connector-nestjs-${wallet}" "$NODE_HOME/bin/node" "$PIVOTAL_CONNECTOR_HOME/dist/main.js" \
      >"$log_file" 2>&1 < /dev/null
  )

  for _ in $(seq 1 30); do
    if pgrep -af "$pattern" >/dev/null 2>&1; then
      pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$pid_file" || true
      if rg -q "Pivotal connector '${CONNECTOR_ID}' is running" "$log_file"; then
        return
      fi
    else
      echo "$name exited during startup; see $log_file" >&2
      exit 1
    fi
    sleep 1
  done

  echo "$name did not become ready; see $log_file" >&2
  exit 1
}

case "$TARGET" in
  all)
    start_connector wallet1 "http://127.0.0.1:8081"
    start_connector wallet2 "http://127.0.0.1:8082"
    print_local_connector_endpoint wallet1
    print_local_connector_endpoint wallet2
    ;;
  wallet1)
    start_connector wallet1 "http://127.0.0.1:8081"
    print_local_connector_endpoint wallet1
    ;;
  wallet2)
    start_connector wallet2 "http://127.0.0.1:8082"
    print_local_connector_endpoint wallet2
    ;;
  *)
    echo "Usage: $0 [all|wallet1|wallet2]" >&2
    exit 1
    ;;
esac
