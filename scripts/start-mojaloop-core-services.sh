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

case "${LOCAL_CLEDG_POSITION_HANDLER:-position}" in
  position)
    position_handler_flag="--position"
    ;;
  positionbatch|batch)
    position_handler_flag="--positionbatch"
    ;;
  *)
    echo "LOCAL_CLEDG_POSITION_HANDLER must be position or positionbatch" >&2
    exit 1
    ;;
esac

start_service central-ledger-api central-ledger 3001 env CLEDG_PROXY_CACHE__enabled=false CLEDG_ENABLE_ON_US_TRANSFERS=true npm run start:api
start_service central-ledger-handlers central-ledger 3011 env CLEDG_PORT=3011 CLEDG_PROXY_CACHE__enabled=false CLEDG_ENABLE_ON_US_TRANSFERS=true node src/handlers/index.js handler --prepare "$position_handler_flag" --fulfil --timeout --get --admin
start_service ml-api-adapter-api ml-api-adapter 3000 env MLAPI_PROXY_CACHE__enabled=false MLAPI_PAYLOAD_CACHE__enabled=false MLAPI_ENDPOINT_CACHE_CONFIG__expiresIn=1000 MLAPI_ENDPOINT_CACHE_CONFIG__generateTimeout=1000 npm run start:api
start_service ml-api-adapter-handler ml-api-adapter 3010 env MLAPI_PORT=3010 MLAPI_PROXY_CACHE__enabled=false MLAPI_PAYLOAD_CACHE__enabled=false MLAPI_ENDPOINT_CACHE_CONFIG__expiresIn=1000 MLAPI_ENDPOINT_CACHE_CONFIG__generateTimeout=1000 node src/handlers/index.js handler --notification
start_service account-lookup-api account-lookup-service 4002 env ALS_PROXY_CACHE__enabled=true ALS_PROXY_CACHE__type=redis ALS_PROXY_CACHE__proxyConfig__host=127.0.0.1 ALS_PROXY_CACHE__proxyConfig__port=6379 npm run start:api
start_service account-lookup-admin account-lookup-service 4001 env ALS_PROXY_CACHE__enabled=true ALS_PROXY_CACHE__type=redis ALS_PROXY_CACHE__proxyConfig__host=127.0.0.1 ALS_PROXY_CACHE__proxyConfig__port=6379 npm run start:admin
start_service account-lookup-handlers account-lookup-service 4003 env ALS_PROXY_CACHE__enabled=true ALS_PROXY_CACHE__type=redis ALS_PROXY_CACHE__proxyConfig__host=127.0.0.1 ALS_PROXY_CACHE__proxyConfig__port=6379 npm run start:handlers
start_service quoting-api quoting-service 3002 env QUOTE_SIMPLE_ROUTING_MODE=false QUOTE_PROXY_CACHE__enabled=false QUOTE_PAYLOAD_CACHE__enabled=false npm run start:api
start_service quoting-handlers quoting-service 3103 env QUOTE_SIMPLE_ROUTING_MODE=false QUOTE_PROXY_CACHE__enabled=false QUOTE_PAYLOAD_CACHE__enabled=false QUOTE_MONITORING_PORT=3103 npm run start:handlers
start_service central-settlement-api central-settlement 3007 npm run start:api
