#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

UI_PORT="${LOCAL_UI_PORT:-3400}"
SERVER_PATH="$LOCAL_HOME/ui/server.mjs"

stop_named_process local-ui "$RUN_DIR/local-ui.pid" "$UI_PORT" "$SERVER_PATH"
