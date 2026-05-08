#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tazama-common.sh"

down_volumes=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --volumes)
      down_volumes=1
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--volumes]" >&2
      exit 1
      ;;
  esac
  shift
done

tazama_init
resolve_tazama_compose_cmd

args=(down --remove-orphans)
if [ "$down_volumes" -eq 1 ]; then
  args+=(--volumes)
fi

run_tazama_compose "${args[@]}"
