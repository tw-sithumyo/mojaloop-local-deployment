#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

"$LOCAL_HOME/scripts/stop-ui.sh"
"$LOCAL_HOME/scripts/stop-reporting-stack.sh" || true
"$LOCAL_HOME/scripts/stop-ppa.sh" || true
"$LOCAL_HOME/scripts/stop-tazama.sh" || true
"$LOCAL_HOME/scripts/stop-delay-proxy.sh" || true
"$LOCAL_HOME/scripts/stop-wallet-services.sh"
"$LOCAL_HOME/scripts/stop-pivotal-connector-services.sh" || true
"$LOCAL_HOME/scripts/stop-demowallet-services.sh" || true
"$LOCAL_HOME/scripts/stop-services.sh"
"$LOCAL_HOME/scripts/stop-infra.sh"
