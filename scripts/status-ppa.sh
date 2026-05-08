#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ppa-common.sh"

ppa_init

print_ppa_summary
echo

if [ -f "$PPA_PID_FILE" ] && kill -0 "$(cat "$PPA_PID_FILE")" 2>/dev/null; then
  echo "Process: running (pid $(cat "$PPA_PID_FILE"))"
elif pgrep -f "$PPA_ENTRYPOINT" >/dev/null 2>&1; then
  echo "Process: running (pid $(pgrep -f "$PPA_ENTRYPOINT" | head -n1))"
else
  echo "Process: not running"
fi

if curl -fsS "http://${PPA_HOST}:${PPA_PORT}/health" >/dev/null 2>&1; then
  echo "Health: UP"
else
  echo "Health: DOWN"
fi

echo "Log file: $PPA_LOG_FILE"
