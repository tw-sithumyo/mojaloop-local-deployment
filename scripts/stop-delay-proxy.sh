#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

PROXY_PORT="${DELAY_PROXY_PORT:-3299}"

stop_named_process payee-delay-proxy "$RUN_DIR/services/payee-delay-proxy.pid" "$PROXY_PORT" 'payee-delay-proxy.js'
