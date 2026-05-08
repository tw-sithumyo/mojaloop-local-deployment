#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ppa-common.sh"

ppa_init

(
  cd "$PPA_HOME"
  npm ci
  npm run build
)
