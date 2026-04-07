#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"

reporting_aggregator_init

if [ ! -f "$REPORTING_AGGREGATOR_LOG_FILE" ]; then
  echo "Reporting Aggregator log file not found: $REPORTING_AGGREGATOR_LOG_FILE" >&2
  exit 1
fi

if [ "${1:-}" = "-f" ]; then
  tail -f "$REPORTING_AGGREGATOR_LOG_FILE"
else
  tail -n "${1:-200}" "$REPORTING_AGGREGATOR_LOG_FILE"
fi
