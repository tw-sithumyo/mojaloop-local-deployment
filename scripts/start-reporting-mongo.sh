#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"

reporting_aggregator_init
require_docker_for_reporting_mongo

if docker inspect "$REPORTING_MONGO_CONTAINER" >/dev/null 2>&1; then
  if [ "$(docker inspect -f '{{.State.Running}}' "$REPORTING_MONGO_CONTAINER")" = "true" ]; then
    echo "Reporting Mongo already running in container $REPORTING_MONGO_CONTAINER"
    exit 0
  fi

  docker start "$REPORTING_MONGO_CONTAINER" >/dev/null
else
  DOCKER_ARGS=(
    run
    -d
    --name "$REPORTING_MONGO_CONTAINER"
    -p "${REPORTING_MONGO_DB_HOST}:${REPORTING_MONGO_DB_PORT}:27017"
    -v "${REPORTING_MONGO_CONTAINER}-data:/data/db"
  )

  if [ -n "${REPORTING_MONGO_DB_USER:-}" ] && [ -n "${REPORTING_MONGO_DB_PASSWORD:-}" ]; then
    DOCKER_ARGS+=(
      -e "MONGO_INITDB_ROOT_USERNAME=${REPORTING_MONGO_DB_USER}"
      -e "MONGO_INITDB_ROOT_PASSWORD=${REPORTING_MONGO_DB_PASSWORD}"
    )
  fi

  DOCKER_ARGS+=("$REPORTING_MONGO_IMAGE")

  docker "${DOCKER_ARGS[@]}" >/dev/null
fi

for _ in $(seq 1 30); do
  if ! docker inspect "$REPORTING_MONGO_CONTAINER" >/dev/null 2>&1; then
    break
  fi

  if [ -n "${REPORTING_MONGO_DB_USER:-}" ] && [ -n "${REPORTING_MONGO_DB_PASSWORD:-}" ]; then
    if docker exec "$REPORTING_MONGO_CONTAINER" mongosh --quiet \
      -u "$REPORTING_MONGO_DB_USER" \
      -p "$REPORTING_MONGO_DB_PASSWORD" \
      --authenticationDatabase admin \
      --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1; then
      echo "Reporting Mongo listening on ${REPORTING_MONGO_DB_HOST}:${REPORTING_MONGO_DB_PORT}"
      exit 0
    fi
  else
    if docker exec "$REPORTING_MONGO_CONTAINER" mongosh --quiet --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1; then
      echo "Reporting Mongo listening on ${REPORTING_MONGO_DB_HOST}:${REPORTING_MONGO_DB_PORT}"
      exit 0
    fi
  fi
  sleep 1
done

echo "Reporting Mongo did not become ready in container $REPORTING_MONGO_CONTAINER" >&2
exit 1
