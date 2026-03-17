#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

UI_HOST="${LOCAL_UI_HOST:-127.0.0.1}"
UI_PORT="${LOCAL_UI_PORT:-3400}"
SERVER_PATH="$LOCAL_HOME/ui/server.mjs"
PID_FILE="$RUN_DIR/local-ui.pid"
LOG_FILE="$LOG_DIR/local-ui.log"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  exit 0
fi

if pgrep -f "$SERVER_PATH" >/dev/null 2>&1; then
  pgrep -f "$SERVER_PATH" | awk 'NR==1 {print $1}' > "$PID_FILE" || true
  exit 0
fi

if ss -ltn | rg -q "[:.]$UI_PORT\\b"; then
  echo "Port $UI_PORT is already in use; cannot start local UI" >&2
  exit 1
fi

: > "$LOG_FILE"
export LOCAL_UI_HOST="$UI_HOST"
export LOCAL_UI_PORT="$UI_PORT"

setsid -f node "$SERVER_PATH" >>"$LOG_FILE" 2>&1 < /dev/null

for _ in $(seq 1 30); do
  if curl -fsS "http://${UI_HOST}:${UI_PORT}/api/status" >/dev/null 2>&1; then
    pgrep -f "$SERVER_PATH" | awk 'NR==1 {print $1}' > "$PID_FILE" || true
    echo "Local UI listening on http://${UI_HOST}:${UI_PORT}"
    exit 0
  fi
  sleep 1
done

echo "Local UI did not become ready on http://${UI_HOST}:${UI_PORT}" >&2
exit 1
