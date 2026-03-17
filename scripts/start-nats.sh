#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

NATS_VERSION="2.12.5"
NATS_ARCHIVE="nats-server-v${NATS_VERSION}-linux-amd64.tar.gz"
NATS_URL="https://github.com/nats-io/nats-server/releases/download/v${NATS_VERSION}/${NATS_ARCHIVE}"
NATS_HOME="$ROOT_DIR/tools/nats-server-v${NATS_VERSION}-linux-amd64"
NATS_BIN="$NATS_HOME/nats-server"

mkdir -p "$DATA_DIR/nats"

if [ ! -x "$NATS_BIN" ]; then
  archive_path="$ROOT_DIR/tools/$NATS_ARCHIVE"
  rm -f "$archive_path"
  curl -fsSL "$NATS_URL" -o "$archive_path"
  tar -xzf "$archive_path" -C "$ROOT_DIR/tools"
fi

if [ -f "$RUN_DIR/nats.pid" ] && kill -0 "$(cat "$RUN_DIR/nats.pid")" 2>/dev/null; then
  exit 0
fi

if ss -ltn | rg -q '[:.]4222\b'; then
  pgrep -af "$NATS_BIN" | awk 'NR==1 {print $1}' > "$RUN_DIR/nats.pid" || true
  exit 0
fi

: > "$LOG_DIR/nats.log"
setsid -f "$NATS_BIN" \
  -js \
  -sd "$DATA_DIR/nats" \
  -a 127.0.0.1 \
  -p 4222 \
  -m 8222 \
  -P "$RUN_DIR/nats.pid" \
  >>"$LOG_DIR/nats.log" 2>&1 < /dev/null

for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8222/healthz >/dev/null 2>&1; then
    pgrep -af "$NATS_BIN" | awk 'NR==1 {print $1}' > "$RUN_DIR/nats.pid" || true
    exit 0
  fi
  sleep 1
done

echo "nats-server did not become healthy on 127.0.0.1:8222" >&2
exit 1
