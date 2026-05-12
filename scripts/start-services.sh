#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

echo "Deprecated: use local/scripts/start-mojaloop-core-services.sh" >&2
exec "$LOCAL_HOME/scripts/start-mojaloop-core-services.sh" "$@"
