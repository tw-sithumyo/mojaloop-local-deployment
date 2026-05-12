#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

ENV_FILE="$CONF_DIR/wallet1-pivotal.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing wallet1 env file: $ENV_FILE" >&2
  exit 1
fi

"$LOCAL_HOME/scripts/start-nats.sh"
"$LOCAL_HOME/scripts/start-demowallet-services.sh" wallet1
"$LOCAL_HOME/scripts/init-pivotal-db.sh"
"$LOCAL_HOME/scripts/sync-wallet1-pivotal-env.sh"

if [ ! -d "$PIVOTAL_HOME/node_modules" ]; then
  "$LOCAL_HOME/scripts/npm-ci-pivotal.sh"
fi

"$LOCAL_HOME/scripts/ensure-wallet1-streams.sh"
"$LOCAL_HOME/scripts/start-pivotal-auditor.sh"
"$LOCAL_HOME/scripts/seed-pivotal-participants.sh"
"$LOCAL_HOME/scripts/start-pivotal-portal-services.sh"

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
    cd "$PIVOTAL_HOME"
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
    cd "$PIVOTAL_HOME"
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

start_service_with_port wallet1-web-inbound 3201 start:apps-web-inbound '(apps-web-inbound|dist/packages/apps/web-inbound/main)'
start_service_with_port wallet1-web-outbound 3200 start:apps-web-outbound '(apps-web-outbound|dist/packages/apps/web-outbound/main)'
"$LOCAL_HOME/scripts/start-pivotal-connector-services.sh" wallet1
