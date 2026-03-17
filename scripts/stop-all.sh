#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

"$LOCAL_HOME/scripts/stop-ui.sh"
"$LOCAL_HOME/scripts/stop-wallet-services.sh"
"$LOCAL_HOME/scripts/stop-services.sh"
"$LOCAL_HOME/scripts/stop-infra.sh"
