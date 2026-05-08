#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ppa-common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

ppa_init

stop_named_process "ppa" "$PPA_PID_FILE" "$PPA_PORT" "$PPA_ENTRYPOINT"
