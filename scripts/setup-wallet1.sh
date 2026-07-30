#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

WALLET_STACK="${WALLET_STACK:-pivotal}"
case "$WALLET_STACK" in
  pivotal)
    "$LOCAL_HOME/scripts/start-nats.sh"
    "$LOCAL_HOME/scripts/npm-ci-pivotal.sh"
    "$LOCAL_HOME/scripts/sync-wallet1-pivotal-env.sh"
    "$LOCAL_HOME/scripts/start-wallet1-services.sh"
    "$LOCAL_HOME/scripts/onboard-wallet1.sh"
    ;;
  core|core-connector)
    WALLET_STACK=core "$LOCAL_HOME/scripts/start-wallet-stack.sh"
    WALLET_STACK=core "$LOCAL_HOME/scripts/onboard-wallet1.sh"
    ;;
  *)
    echo "Unsupported WALLET_STACK: $WALLET_STACK (expected pivotal or core)" >&2
    exit 1
    ;;
esac
