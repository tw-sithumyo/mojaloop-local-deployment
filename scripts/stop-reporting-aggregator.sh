#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

reporting_aggregator_init

stop_named_process "reporting-aggregator" "$REPORTING_AGGREGATOR_PID_FILE" "" "$REPORTING_AGGREGATOR_ENTRYPOINT"
