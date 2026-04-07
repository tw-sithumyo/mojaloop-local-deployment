#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"

reporting_aggregator_init

print_reporting_aggregator_summary
echo

if [ -f "$REPORTING_AGGREGATOR_PID_FILE" ] && kill -0 "$(cat "$REPORTING_AGGREGATOR_PID_FILE")" 2>/dev/null; then
  echo "Process: running (pid $(cat "$REPORTING_AGGREGATOR_PID_FILE"))"
elif pgrep -f "$REPORTING_AGGREGATOR_ENTRYPOINT" >/dev/null 2>&1; then
  echo "Process: running (pid $(pgrep -f "$REPORTING_AGGREGATOR_ENTRYPOINT" | head -n1))"
else
  echo "Process: not running"
fi

echo "Log file: $REPORTING_AGGREGATOR_LOG_FILE"
