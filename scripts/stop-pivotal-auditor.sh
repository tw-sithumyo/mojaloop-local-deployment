#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
source "$LOCAL_HOME/scripts/stop-common.sh"

stop_named_process pivotal-app-auditor "$RUN_DIR/pivotal-app-auditor.pid" "" '(apps-app-auditor|dist/packages/apps/app-auditor/main)'
