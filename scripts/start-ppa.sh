#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ppa-common.sh"

ppa_init
ensure_ppa_dependencies

if [ -f "$PPA_PID_FILE" ] && kill -0 "$(cat "$PPA_PID_FILE")" 2>/dev/null; then
  exit 0
fi

if pgrep -f "$PPA_ENTRYPOINT" >/dev/null 2>&1; then
  pgrep -f "$PPA_ENTRYPOINT" | awk 'NR==1 {print $1}' > "$PPA_PID_FILE" || true
  exit 0
fi

if ss -ltn | rg -q "[:.]$PPA_PORT\\b"; then
  echo "Port $PPA_PORT is already in use; cannot start PPA" >&2
  exit 1
fi

: > "$PPA_LOG_FILE"

(
  cd "$PPA_HOME"
  npm run build >>"$PPA_LOG_FILE" 2>&1
)

(
  cd "$PPA_HOME"
  setsid -f env \
    FUNCTION_NAME="$FUNCTION_NAME" \
    PORT="$PPA_PORT" \
    TMS_ENDPOINT="$TMS_ENDPOINT" \
    TMS_PAIN001_ENDPOINT="$TMS_PAIN001_ENDPOINT" \
    TMS_PAIN013_ENDPOINT="$TMS_PAIN013_ENDPOINT" \
    TMS_PACS008_ENDPOINT="$TMS_PACS008_ENDPOINT" \
    TMS_PACS002_ENDPOINT="$TMS_PACS002_ENDPOINT" \
    KAFKA_URI="$KAFKA_URI" \
    KAFKA_CLIENT_ID="$KAFKA_CLIENT_ID" \
    KAFKA_CONSUMER_GROUP="$KAFKA_CONSUMER_GROUP" \
    KAFKA_TOPIC_TO_CONSUME="$KAFKA_TOPIC_TO_CONSUME" \
    REDIS_URL="$REDIS_URL" \
    REDIS_PORT="$REDIS_PORT" \
    NODE_ENV="$NODE_ENV" \
    node "$PPA_ENTRYPOINT" >>"$PPA_LOG_FILE" 2>&1 < /dev/null
)

for _ in $(seq 1 30); do
  if curl -fsS "http://${PPA_HOST}:${PPA_PORT}/health" >/dev/null 2>&1; then
    pgrep -f "$PPA_ENTRYPOINT" | awk 'NR==1 {print $1}' > "$PPA_PID_FILE" || true
    echo "PPA listening on http://${PPA_HOST}:${PPA_PORT}"
    echo "Kafka topic: $KAFKA_TOPIC_TO_CONSUME"
    exit 0
  fi
  sleep 1
done

echo "PPA did not become ready on http://${PPA_HOST}:${PPA_PORT}" >&2
exit 1
