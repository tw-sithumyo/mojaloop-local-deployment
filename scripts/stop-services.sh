#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

mkdir -p "$RUN_DIR/services"

stop_named_process central-ledger-api "$RUN_DIR/services/central-ledger-api.pid" 3001
stop_named_process central-ledger-handlers "$RUN_DIR/services/central-ledger-handlers.pid" 3011 'src/handlers/index.js handler --prepare'
stop_named_process ml-api-adapter-api "$RUN_DIR/services/ml-api-adapter-api.pid" 3000
stop_named_process ml-api-adapter-handler "$RUN_DIR/services/ml-api-adapter-handler.pid" 3010 'src/handlers/index.js handler --notification'
stop_named_process account-lookup-api "$RUN_DIR/services/account-lookup-api.pid" 4002
stop_named_process account-lookup-admin "$RUN_DIR/services/account-lookup-admin.pid" 4001
stop_named_process account-lookup-handlers "$RUN_DIR/services/account-lookup-handlers.pid" 4003
stop_named_process quoting-api "$RUN_DIR/services/quoting-api.pid" 3002
stop_named_process quoting-handlers "$RUN_DIR/services/quoting-handlers.pid" 3103
stop_named_process central-settlement-api "$RUN_DIR/services/central-settlement-api.pid" 3007

rm -f \
  "$RUN_DIR/services/central-settlement-handlers.pid"
