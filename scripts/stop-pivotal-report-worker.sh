#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

stop_named_process \
  pivotal-report-worker \
  "$RUN_DIR/pivotal-report-worker.pid" \
  "" \
  '(apps-report-worker|dist/packages/apps/report-worker/main)'
