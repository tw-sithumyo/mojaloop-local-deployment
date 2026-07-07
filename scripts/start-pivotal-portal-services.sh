#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
source "$LOCAL_HOME/scripts/print-local-endpoints.sh"

WEB_PIVOTAL_ENV_FILE="$PIVOTAL_HOME/packages/apps/web-pivotal/.env"
PIVOTAL_PORTAL_ENV_FILE="$PIVOTAL_HOME/packages/portal/.env"

if [ ! -f "$PIVOTAL_HOME/package.json" ]; then
  echo "Missing Pivotal repo: $PIVOTAL_HOME/package.json" >&2
  exit 1
fi

if [ ! -f "$WEB_PIVOTAL_ENV_FILE" ]; then
  echo "Missing web-pivotal env file: $WEB_PIVOTAL_ENV_FILE" >&2
  echo "Run local/scripts/sync-wallet1-pivotal-env.sh or local/scripts/sync-wallet2-pivotal-env.sh first." >&2
  exit 1
fi

set -a
source "$WEB_PIVOTAL_ENV_FILE"
if [ -f "$PIVOTAL_PORTAL_ENV_FILE" ]; then
  source "$PIVOTAL_PORTAL_ENV_FILE"
fi
set +a

WEB_PIVOTAL_PORT="${WEB_PIVOTAL_PORT:-3202}"
PIVOTAL_PORTAL_PORT="${PIVOTAL_PORTAL_PORT:-4173}"
VITE_WEB_PIVOTAL_API_BASE_URL="${VITE_WEB_PIVOTAL_API_BASE_URL:-http://localhost:${WEB_PIVOTAL_PORT}}"

if [ ! -d "$PIVOTAL_HOME/node_modules" ] || [ ! -d "$PIVOTAL_HOME/packages/portal/node_modules" ]; then
  "$LOCAL_HOME/scripts/npm-ci-pivotal.sh"
fi

pid_for_port() {
  local port="$1"
  ss -ltnp "( sport = :$port )" 2>/dev/null \
    | rg -o 'pid=[0-9]+' \
    | cut -d= -f2 \
    | sort -u \
    | head -n 1 || true
}

record_pid() {
  local port="$1"
  local pattern="$2"
  local pid_file="$3"
  local pid

  pid="$(pid_for_port "$port")"
  if [ -z "$pid" ]; then
    pid="$(pgrep -af "$pattern" | awk 'NR==1 {print $1}' || true)"
  fi
  if [ -n "$pid" ]; then
    echo "$pid" > "$pid_file"
  fi
}

start_service_with_port() {
  local name="$1"
  local workdir="$2"
  local port="$3"
  local pattern="$4"
  shift 4

  local log_file="$LOG_DIR/$name.log"
  local pid_file="$RUN_DIR/$name.pid"

  if ss -ltn | rg -q "[:.]$port\\b"; then
    record_pid "$port" "$pattern" "$pid_file"
    return
  fi

  if pgrep -af "$pattern" >/dev/null 2>&1; then
    record_pid "$port" "$pattern" "$pid_file"
    return
  fi

  (
    cd "$workdir"
    : >"$log_file"
    setsid "$@" >"$log_file" 2>&1 < /dev/null &
    echo "$!" > "$pid_file"
  )

  for _ in $(seq 1 90); do
    if ss -ltn | rg -q "[:.]$port\\b"; then
      record_pid "$port" "$pattern" "$pid_file"
      return
    fi
    sleep 1
  done

  echo "$name did not start listening on port $port; see $log_file" >&2
  exit 1
}

start_service_with_port \
  pivotal-web-pivotal \
  "$PIVOTAL_HOME" \
  "$WEB_PIVOTAL_PORT" \
  '(apps-web-pivotal|dist/packages/apps/web-pivotal/main)' \
  npm run start:apps-web-pivotal

"$LOCAL_HOME/scripts/start-pivotal-report-worker.sh"

start_service_with_port \
  pivotal-portal \
  "$PIVOTAL_HOME/packages/portal" \
  "$PIVOTAL_PORTAL_PORT" \
  "(vite.*${PIVOTAL_PORTAL_PORT}|packages/portal)" \
  env VITE_WEB_PIVOTAL_API_BASE_URL="$VITE_WEB_PIVOTAL_API_BASE_URL" \
    "$PIVOTAL_HOME/packages/portal/node_modules/.bin/vite" \
    --host 127.0.0.1 \
    --port "$PIVOTAL_PORTAL_PORT"

print_local_pivotal_endpoints
