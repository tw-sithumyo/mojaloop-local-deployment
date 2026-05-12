#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

set -a
if [ -f "$PIVOTAL_HOME/packages/apps/web-pivotal/.env" ]; then
  source "$PIVOTAL_HOME/packages/apps/web-pivotal/.env"
fi
if [ -f "$PIVOTAL_HOME/packages/portal/.env" ]; then
  source "$PIVOTAL_HOME/packages/portal/.env"
fi
set +a

WEB_PIVOTAL_PORT="${WEB_PIVOTAL_PORT:-3202}"
PIVOTAL_PORTAL_PORT="${PIVOTAL_PORTAL_PORT:-4173}"

stop_named_process \
  pivotal-portal \
  "$RUN_DIR/pivotal-portal.pid" \
  "$PIVOTAL_PORTAL_PORT" \
  "(vite.*${PIVOTAL_PORTAL_PORT}|packages/portal)"

stop_named_process \
  pivotal-web-pivotal \
  "$RUN_DIR/pivotal-web-pivotal.pid" \
  "$WEB_PIVOTAL_PORT" \
  '(apps-web-pivotal|dist/packages/apps/web-pivotal/main)'
