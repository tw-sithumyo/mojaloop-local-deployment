#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

"$LOCAL_HOME/scripts/start-wallet-stack.sh"
"$LOCAL_HOME/scripts/onboard-wallet1.sh"
