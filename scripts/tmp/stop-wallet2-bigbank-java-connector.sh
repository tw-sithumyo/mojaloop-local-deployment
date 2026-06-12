#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/env.sh"

stop_pid_file() {
  local name="$1"
  local pid_file="$2"
  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    kill "$(cat "$pid_file")"
    echo "$name: stopped pid $(cat "$pid_file")"
  fi
}

stop_pid_file wallet2-bigbank-java-connector "$RUN_DIR/wallet2-pivotal-connector.pid"
stop_pid_file pivotal-bigbank-mock "$RUN_DIR/pivotal-bigbank-mock.pid"

if pgrep -f '^pivotal-gin-big-bank-java-connector-wallet2 ' >/dev/null 2>&1; then
  pgrep -f '^pivotal-gin-big-bank-java-connector-wallet2 ' | xargs -r kill
fi
