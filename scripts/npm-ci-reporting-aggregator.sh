#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"

reporting_aggregator_init

(
  cd "$REPORTING_AGGREGATOR_HOME"
  npm ci
  npm run build
)
