#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"

reporting_aggregator_init

"$LOCAL_HOME/scripts/status-reporting-aggregator.sh"

if [ "$REPORTING_MONGO_MANAGED" = "1" ]; then
  echo
  "$LOCAL_HOME/scripts/status-reporting-mongo.sh"
fi
