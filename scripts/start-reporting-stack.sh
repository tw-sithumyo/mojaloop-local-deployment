#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"
source "$LOCAL_HOME/scripts/print-local-endpoints.sh"

reporting_aggregator_init

if [ "$REPORTING_MONGO_MANAGED" = "1" ]; then
  "$LOCAL_HOME/scripts/start-reporting-mongo.sh"
fi

"$LOCAL_HOME/scripts/start-reporting-aggregator.sh"
print_local_reporting_endpoints
