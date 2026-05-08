#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tazama-common.sh"

tazama_init
resolve_tazama_compose_cmd

if [ "$#" -eq 0 ]; then
  run_tazama_compose logs --tail 200
else
  run_tazama_compose logs --tail 200 "$@"
fi
