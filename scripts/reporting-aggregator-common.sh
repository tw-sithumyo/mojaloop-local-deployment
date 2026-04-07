#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

find_reporting_aggregator_root() {
  local candidate

  for candidate in \
    "${REPORTING_AGGREGATOR_HOME:-}" \
    "$ROOT_DIR/reporting-aggregator-svc"
  do
    [ -n "$candidate" ] || continue
    if [ -d "$candidate" ] && [ -f "$candidate/package.json" ]; then
      REPORTING_AGGREGATOR_HOME="$candidate"
      export REPORTING_AGGREGATOR_HOME
      return 0
    fi
  done

  echo "Unable to find reporting-aggregator-svc. Set REPORTING_AGGREGATOR_HOME or clone it under $ROOT_DIR/reporting-aggregator-svc." >&2
  exit 1
}

load_reporting_aggregator_env() {
  local env_file="${REPORTING_AGGREGATOR_ENV_FILE:-$CONF_DIR/reporting-aggregator.env}"

  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi

  export REPORTING_AGGREGATOR_ENV_FILE="$env_file"
}

normalize_reporting_aggregator_defaults() {
  LOG_LEVEL="${LOG_LEVEL:-info}"

  REPORTING_MYSQL_DB_HOST="${REPORTING_MYSQL_DB_HOST:-127.0.0.1}"
  REPORTING_MYSQL_DB_PORT="${REPORTING_MYSQL_DB_PORT:-3306}"
  REPORTING_MYSQL_DB_USER="${REPORTING_MYSQL_DB_USER:-central_ledger}"
  REPORTING_MYSQL_DB_PASSWORD="${REPORTING_MYSQL_DB_PASSWORD:-password}"
  REPORTING_MYSQL_DB_SCHEMA="${REPORTING_MYSQL_DB_SCHEMA:-central_ledger}"

  REPORTING_MONGO_DB_HOST="${REPORTING_MONGO_DB_HOST:-127.0.0.1}"
  REPORTING_MONGO_DB_PORT="${REPORTING_MONGO_DB_PORT:-27017}"
  REPORTING_MONGO_DB_USER="${REPORTING_MONGO_DB_USER:-}"
  REPORTING_MONGO_DB_PASSWORD="${REPORTING_MONGO_DB_PASSWORD:-}"
  REPORTING_MONGO_DB_DATABASE="${REPORTING_MONGO_DB_DATABASE:-reporting}"

  BATCH_SIZE="${BATCH_SIZE:-10000}"
  TRANSFER_DETAILS_BATCH_SIZE="${TRANSFER_DETAILS_BATCH_SIZE:-10000}"
  LOOP_TIMEOUT="${LOOP_TIMEOUT:-5000}"
  MIN_BATCH_PERCENTAGE="${MIN_BATCH_PERCENTAGE:-70}"
  MAX_WAIT_COUNT="${MAX_WAIT_COUNT:-3}"

  REPORTING_MONGO_MANAGED="${REPORTING_MONGO_MANAGED:-0}"
  REPORTING_MONGO_IMAGE="${REPORTING_MONGO_IMAGE:-mongo:6}"
  REPORTING_MONGO_CONTAINER="${REPORTING_MONGO_CONTAINER:-local-reporting-mongo}"

  REPORTING_AGGREGATOR_ENTRYPOINT="$REPORTING_AGGREGATOR_HOME/dist/index.js"
  REPORTING_AGGREGATOR_PID_FILE="$RUN_DIR/reporting-aggregator.pid"
  REPORTING_AGGREGATOR_LOG_FILE="$LOG_DIR/reporting-aggregator.log"

  export LOG_LEVEL
  export REPORTING_MYSQL_DB_HOST REPORTING_MYSQL_DB_PORT REPORTING_MYSQL_DB_USER REPORTING_MYSQL_DB_PASSWORD REPORTING_MYSQL_DB_SCHEMA
  export REPORTING_MONGO_DB_HOST REPORTING_MONGO_DB_PORT REPORTING_MONGO_DB_USER REPORTING_MONGO_DB_PASSWORD REPORTING_MONGO_DB_DATABASE
  export BATCH_SIZE TRANSFER_DETAILS_BATCH_SIZE LOOP_TIMEOUT MIN_BATCH_PERCENTAGE MAX_WAIT_COUNT
  export REPORTING_MONGO_MANAGED REPORTING_MONGO_IMAGE REPORTING_MONGO_CONTAINER
  export REPORTING_AGGREGATOR_ENTRYPOINT REPORTING_AGGREGATOR_PID_FILE REPORTING_AGGREGATOR_LOG_FILE
}

reporting_aggregator_init() {
  load_reporting_aggregator_env
  find_reporting_aggregator_root
  normalize_reporting_aggregator_defaults
}

print_reporting_aggregator_summary() {
  echo "Reporting Aggregator root: $REPORTING_AGGREGATOR_HOME"
  echo "Reporting Aggregator env file: $REPORTING_AGGREGATOR_ENV_FILE"
  echo "MySQL source: ${REPORTING_MYSQL_DB_HOST}:${REPORTING_MYSQL_DB_PORT}/${REPORTING_MYSQL_DB_SCHEMA}"
  echo "Mongo target: ${REPORTING_MONGO_DB_HOST}:${REPORTING_MONGO_DB_PORT}/${REPORTING_MONGO_DB_DATABASE}"
  echo "Managed Mongo: $REPORTING_MONGO_MANAGED"
  echo "Batch size: $BATCH_SIZE"
  echo "Transfer details batch size: $TRANSFER_DETAILS_BATCH_SIZE"
  echo "Loop timeout: $LOOP_TIMEOUT"
}

require_docker_for_reporting_mongo() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Managed reporting Mongo needs Docker on PATH." >&2
    exit 1
  fi
}
