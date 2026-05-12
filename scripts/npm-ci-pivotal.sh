#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

(
  cd "$PIVOTAL_HOME"
  npm ci
)

(
  cd "$PIVOTAL_HOME/packages/portal"
  npm ci
)
