#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

"$LOCAL_HOME/scripts/start-nats.sh"
"$LOCAL_HOME/scripts/npm-ci-pivotal.sh"
"$LOCAL_HOME/scripts/sync-wallet1-pivotal-env.sh"
"$LOCAL_HOME/scripts/start-wallet1-services.sh"
"$LOCAL_HOME/scripts/onboard-wallet1.sh"
