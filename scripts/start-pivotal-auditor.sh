#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
source "$LOCAL_HOME/scripts/print-local-endpoints.sh"

name="pivotal-app-auditor"
log_file="$LOG_DIR/$name.log"
pid_file="$RUN_DIR/$name.pid"
pattern='(apps-app-auditor|dist/packages/apps/app-auditor/main)'

if [ ! -f "$PIVOTAL_HOME/package.json" ]; then
  echo "Missing Pivotal repo: $PIVOTAL_HOME/package.json" >&2
  exit 1
fi

if [ ! -f "$PIVOTAL_HOME/packages/apps/app-auditor/.env" ]; then
  echo "Missing app-auditor env file: $PIVOTAL_HOME/packages/apps/app-auditor/.env" >&2
  exit 1
fi

if [ ! -d "$PIVOTAL_HOME/node_modules" ]; then
  "$LOCAL_HOME/scripts/npm-ci-pivotal.sh"
fi

if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
  print_local_app_auditor_endpoint
  exit 0
fi

if pgrep -af "$pattern" >/dev/null 2>&1; then
  pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$pid_file" || true
  print_local_app_auditor_endpoint
  exit 0
fi

(
  cd "$PIVOTAL_HOME"
  : >"$log_file"
  setsid -f npm run start:apps-app-auditor >"$log_file" 2>&1 < /dev/null
)

for _ in $(seq 1 90); do
  if pgrep -af "$pattern" >/dev/null 2>&1; then
    pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$pid_file" || true
    if rg -q "Audit consumer is running" "$log_file"; then
      print_local_app_auditor_endpoint
      exit 0
    fi
  fi
  sleep 1
done

echo "$name did not become ready; see $log_file" >&2
exit 1
