#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

if [ ! -f "$PIVOTAL_CONNECTOR_HOME/package-lock.json" ]; then
  echo "Missing pivotal connector package-lock.json: $PIVOTAL_CONNECTOR_HOME/package-lock.json" >&2
  exit 1
fi

(
  cd "$PIVOTAL_CONNECTOR_HOME"
  npm ci
)
