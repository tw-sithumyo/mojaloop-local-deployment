#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tazama-common.sh"

tazama_init
resolve_tazama_compose_cmd

print_tazama_summary
echo
run_tazama_compose ps
