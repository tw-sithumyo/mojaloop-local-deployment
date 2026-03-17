#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

ENV_FILE="$CONF_DIR/wallet2-mtpa.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing wallet2 env file: $ENV_FILE" >&2
  exit 1
fi

"$LOCAL_HOME/scripts/start-nats.sh"
"$LOCAL_HOME/scripts/sync-wallet2-mtpa-env.sh"

if [ ! -d "$ROOT_DIR/mtpa/node_modules" ]; then
  "$LOCAL_HOME/scripts/npm-ci-wallet1.sh"
fi

"$LOCAL_HOME/scripts/ensure-wallet2-streams.sh"

start_service_with_port() {
  local name="$1"
  local port="$2"
  local script_name="$3"
  local pattern="$4"

  if ss -ltn | rg -q "[:.]$port\\b"; then
    pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$RUN_DIR/$name.pid" || true
    return
  fi

  if pgrep -af "$pattern" >/dev/null 2>&1; then
    pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$RUN_DIR/$name.pid" || true
    return
  fi

  (
    cd "$ROOT_DIR/mtpa"
    : >"$LOG_DIR/$name.log"
    setsid -f npm run "$script_name" >"$LOG_DIR/$name.log" 2>&1 < /dev/null
  )

  for _ in $(seq 1 60); do
    if ss -ltn | rg -q "[:.]$port\\b"; then
      pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$RUN_DIR/$name.pid" || true
      return
    fi
    sleep 1
  done

  echo "$name did not start listening on port $port" >&2
  exit 1
}

start_service_without_port() {
  local name="$1"
  local script_name="$2"
  local pattern="$3"

  if pgrep -af "$pattern" >/dev/null 2>&1; then
    pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$RUN_DIR/$name.pid" || true
    return
  fi

  (
    cd "$ROOT_DIR/mtpa"
    : >"$LOG_DIR/$name.log"
    setsid -f npm run "$script_name" >"$LOG_DIR/$name.log" 2>&1 < /dev/null
  )

  sleep 5

  if ! pgrep -af "$pattern" >/dev/null 2>&1; then
    echo "$name did not stay running" >&2
    exit 1
  fi

  pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$RUN_DIR/$name.pid" || true
}

start_service_with_port wallet2-web-inbound 3201 start:apps-web-inbound '(apps-web-inbound|dist/packages/apps/web-inbound/main)'
start_service_with_port wallet2-web-outbound 3200 start:apps-web-outbound '(apps-web-outbound|dist/packages/apps/web-outbound/main)'
start_service_without_port wallet2-connector start:samples-wallet2-connector '(samples-wallet2-connector|dist/packages/samples/wallet2-connector/main)'
