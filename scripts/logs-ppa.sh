#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ppa-common.sh"

ppa_init

if [ ! -f "$PPA_LOG_FILE" ]; then
  echo "PPA log file not found: $PPA_LOG_FILE" >&2
  exit 1
fi

if [ "${1:-}" = "-f" ]; then
  tail -f "$PPA_LOG_FILE"
else
  tail -n "${1:-200}" "$PPA_LOG_FILE"
fi
