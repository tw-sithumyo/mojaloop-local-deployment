#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"
source "$LOCAL_HOME/scripts/operation-portal-common.sh"

operation_portal_init

stop_named_process \
  operation-portal \
  "$OPERATION_PORTAL_PID_FILE" \
  "$OPERATION_PORTAL_PORT" \
  'operation_api\.jar:lib/\*.*WebApiOperationPortalApplication'
