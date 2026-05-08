#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

mkdir -p "$RUN_DIR/services"

PROXY_PORT="${DELAY_PROXY_PORT:-3299}"
PROXY_TARGET="${DELAY_PROXY_TARGET:-http://127.0.0.1:3201}"
PROXY_DELAY_MS="${DELAY_PROXY_DELAY_MS:-17000}"
PROXY_LOG="$LOG_DIR/payee-delay-proxy.log"

if ss -ltn | rg -q "[:.]$PROXY_PORT\\b"; then
  echo "payee-delay-proxy already listening on port $PROXY_PORT"
  exit 0
fi

: >"$PROXY_LOG"
(
  cd "$LOCAL_HOME"
  setsid -f env \
    DELAY_PROXY_PORT="$PROXY_PORT" \
    DELAY_PROXY_TARGET="$PROXY_TARGET" \
    DELAY_PROXY_DELAY_MS="$PROXY_DELAY_MS" \
    node "$LOCAL_HOME/scripts/payee-delay-proxy.js" >"$PROXY_LOG" 2>&1 < /dev/null
)

for _ in $(seq 1 20); do
  if ss -ltn | rg -q "[:.]$PROXY_PORT\\b"; then
    pgrep -af "payee-delay-proxy.js" | awk 'NR==1 {print $1}' > "$RUN_DIR/services/payee-delay-proxy.pid" || true
    echo "payee-delay-proxy listening on $PROXY_PORT -> $PROXY_TARGET with ${PROXY_DELAY_MS}ms POST /transfers delay"
    exit 0
  fi
  sleep 1
done

echo "payee-delay-proxy did not start listening on port $PROXY_PORT" >&2
exit 1
