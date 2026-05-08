#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tazama-common.sh"

print_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --print-cmd|--dry-run)
      print_only=1
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--print-cmd]" >&2
      exit 1
      ;;
  esac
  shift
done

tazama_init

if [ "$print_only" -eq 1 ]; then
  print_tazama_summary
  echo "Command:"
  print_tazama_compose_command
  printf " up -d --remove-orphans\n"
  exit 0
fi

resolve_tazama_compose_cmd

print_tazama_summary
echo "Starting Tazama..."
run_tazama_compose up -d --remove-orphans

echo
run_tazama_compose ps

echo
echo "Useful endpoints:"
echo "  TMS Swagger: http://127.0.0.1:${TMS_PORT}/documentation"
echo "  Admin Swagger: http://127.0.0.1:${ADMIN_PORT}/documentation"
if is_true "$TAZAMA_ENABLE_UI"; then
  echo "  Demo UI: http://127.0.0.1:3001"
fi
if is_true "$TAZAMA_ENABLE_PGADMIN"; then
  echo "  pgAdmin: http://127.0.0.1:${PGADMIN_PORT}"
fi
if is_true "$TAZAMA_ENABLE_HASURA"; then
  echo "  Hasura: http://127.0.0.1:6100"
fi
