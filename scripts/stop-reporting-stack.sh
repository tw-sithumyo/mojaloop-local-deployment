#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"

reporting_aggregator_init

"$LOCAL_HOME/scripts/stop-reporting-aggregator.sh"

if [ "$REPORTING_MONGO_MANAGED" = "1" ]; then
  "$LOCAL_HOME/scripts/stop-reporting-mongo.sh"
fi
