#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

stop_named_process wallet1-pivotal-connector "$RUN_DIR/wallet1-pivotal-connector.pid" "" 'pivotal-connector-nestjs-wallet1'
stop_named_process wallet2-pivotal-connector "$RUN_DIR/wallet2-pivotal-connector.pid" "" 'pivotal-connector-nestjs-wallet2'
