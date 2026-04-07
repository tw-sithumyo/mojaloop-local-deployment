#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reporting-aggregator-common.sh"

reporting_aggregator_init
require_docker_for_reporting_mongo

if ! docker inspect "$REPORTING_MONGO_CONTAINER" >/dev/null 2>&1; then
  echo "reporting-mongo: not running"
  exit 0
fi

if [ "$(docker inspect -f '{{.State.Running}}' "$REPORTING_MONGO_CONTAINER")" = "true" ]; then
  docker stop "$REPORTING_MONGO_CONTAINER" >/dev/null
  echo "reporting-mongo: stopped container $REPORTING_MONGO_CONTAINER"
else
  echo "reporting-mongo: already stopped"
fi
