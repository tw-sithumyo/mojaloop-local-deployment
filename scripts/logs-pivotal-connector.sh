#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

TARGET="${1:-all}"

case "$TARGET" in
  all)
    tail -n 200 -f "$LOG_DIR/wallet1-pivotal-connector.log" "$LOG_DIR/wallet2-pivotal-connector.log"
    ;;
  wallet1|wallet2)
    tail -n 200 -f "$LOG_DIR/${TARGET}-pivotal-connector.log"
    ;;
  *)
    echo "Usage: $0 [all|wallet1|wallet2]" >&2
    exit 1
    ;;
esac
