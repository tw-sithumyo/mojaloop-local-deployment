#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"

reporting_aggregator_init
require_docker_for_reporting_mongo

echo "Reporting Mongo container: $REPORTING_MONGO_CONTAINER"
echo "Reporting Mongo image: $REPORTING_MONGO_IMAGE"
echo "Reporting Mongo target: ${REPORTING_MONGO_DB_HOST}:${REPORTING_MONGO_DB_PORT}"

if ! docker inspect "$REPORTING_MONGO_CONTAINER" >/dev/null 2>&1; then
  echo "Status: not created"
  exit 0
fi

echo "Status: $(docker inspect -f '{{.State.Status}}' "$REPORTING_MONGO_CONTAINER")"
