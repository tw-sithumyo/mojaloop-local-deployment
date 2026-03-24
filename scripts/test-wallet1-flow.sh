#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
exec "$LOCAL_HOME/scripts/test-wallet1-wallet2-flow.sh"
