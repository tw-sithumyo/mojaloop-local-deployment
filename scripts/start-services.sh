#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

mkdir -p "$RUN_DIR/services"

"$LOCAL_HOME/scripts/seed-ledger-reference-data.sh"

start_service() {
  local name="$1"
  local repo="$2"
  local port="$3"
  shift 3
  if ss -ltn | rg -q "[:.]$port\\b"; then
    return
  fi
  (
    cd "$ROOT_DIR/$repo"
    : >"$LOG_DIR/$name.log"
    setsid -f "$@" >"$LOG_DIR/$name.log" 2>&1 < /dev/null
  )
}

start_service central-ledger-api central-ledger 3001 env CLEDG_PROXY_CACHE__enabled=false CLEDG_ENABLE_ON_US_TRANSFERS=true npm run start:api
start_service ml-api-adapter-api ml-api-adapter 3000 env MLAPI_PROXY_CACHE__enabled=false MLAPI_PAYLOAD_CACHE__enabled=false npm run start:api
start_service account-lookup-api account-lookup-service 4002 env ALS_PROXY_CACHE__enabled=true ALS_PROXY_CACHE__type=redis ALS_PROXY_CACHE__proxyConfig__host=127.0.0.1 ALS_PROXY_CACHE__proxyConfig__port=6379 npm run start:api
start_service account-lookup-admin account-lookup-service 4001 env ALS_PROXY_CACHE__enabled=true ALS_PROXY_CACHE__type=redis ALS_PROXY_CACHE__proxyConfig__host=127.0.0.1 ALS_PROXY_CACHE__proxyConfig__port=6379 npm run start:admin
start_service account-lookup-handlers account-lookup-service 4003 env ALS_PROXY_CACHE__enabled=true ALS_PROXY_CACHE__type=redis ALS_PROXY_CACHE__proxyConfig__host=127.0.0.1 ALS_PROXY_CACHE__proxyConfig__port=6379 npm run start:handlers
start_service quoting-api quoting-service 3002 env QUOTE_SIMPLE_ROUTING_MODE=false QUOTE_PROXY_CACHE__enabled=false QUOTE_PAYLOAD_CACHE__enabled=false npm run start:api
start_service quoting-handlers quoting-service 3103 env QUOTE_SIMPLE_ROUTING_MODE=false QUOTE_PROXY_CACHE__enabled=false QUOTE_PAYLOAD_CACHE__enabled=false QUOTE_MONITORING_PORT=3103 npm run start:handlers
start_service central-settlement-api central-settlement 3007 npm run start:api
