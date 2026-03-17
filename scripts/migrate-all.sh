#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

for repo in central-ledger account-lookup-service; do
  (
    cd "$ROOT_DIR/$repo"
    npm run migrate
  )
done
