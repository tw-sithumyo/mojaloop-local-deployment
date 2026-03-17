#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

REPOS=(
  central-ledger
  account-lookup-service
  ml-api-adapter
  quoting-service
  central-settlement
)

for repo in "${REPOS[@]}"; do
  (
    cd "$ROOT_DIR/$repo"
    npm ci
  )
done
