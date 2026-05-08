#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

is_true() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

find_tazama_stack_root() {
  local candidate

  for candidate in \
    "${TAZAMA_STACK_ROOT:-}" \
    "$ROOT_DIR/Tazama/Full-Stack-Docker-Tazama" \
    "$ROOT_DIR/Full-Stack-Docker-Tazama"
  do
    [ -n "$candidate" ] || continue
    if [ -d "$candidate" ] && [ -f "$candidate/docker-compose.base.infrastructure.yaml" ]; then
      TAZAMA_STACK_ROOT="$candidate"
      export TAZAMA_STACK_ROOT
      return 0
    fi
  done

  echo "Unable to find Full-Stack-Docker-Tazama. Set TAZAMA_STACK_ROOT or clone it under $ROOT_DIR/Tazama/Full-Stack-Docker-Tazama." >&2
  exit 1
}

load_tazama_env() {
  local env_file="${TAZAMA_ENV_FILE:-$CONF_DIR/tazama.env}"

  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi

  export TAZAMA_ENV_FILE="$env_file"
}

normalize_tazama_defaults() {
  TAZAMA_STACK_TYPE="${TAZAMA_STACK_TYPE:-public-dockerhub}"
  TAZAMA_VERSION="${TAZAMA_VERSION:-rc}"
  TAZAMA_PROJECT_NAME="${TAZAMA_PROJECT_NAME:-tazama}"

  TAZAMA_ENABLE_AUTH="${TAZAMA_ENABLE_AUTH:-0}"
  TAZAMA_ENABLE_RELAY="${TAZAMA_ENABLE_RELAY:-1}"
  TAZAMA_ENABLE_BASIC_LOGS="${TAZAMA_ENABLE_BASIC_LOGS:-0}"
  TAZAMA_ENABLE_UI="${TAZAMA_ENABLE_UI:-0}"
  TAZAMA_ENABLE_NATS_UTILS="${TAZAMA_ENABLE_NATS_UTILS:-0}"
  TAZAMA_ENABLE_BATCH_PPA="${TAZAMA_ENABLE_BATCH_PPA:-0}"
  TAZAMA_ENABLE_PGADMIN="${TAZAMA_ENABLE_PGADMIN:-0}"
  TAZAMA_ENABLE_HASURA="${TAZAMA_ENABLE_HASURA:-0}"

  TMS_PORT="${TMS_PORT:-5000}"
  ADMIN_PORT="${ADMIN_PORT:-5100}"
  POSTGRES_PORT="${POSTGRES_PORT:-15432}"
  PGADMIN_PORT="${PGADMIN_PORT:-15050}"
  APMSERVER_PORT="${APMSERVER_PORT:-8200}"
  ES_PORT="${ES_PORT:-9200}"
  EVENT_SIDECAR_PORT="${EVENT_SIDECAR_PORT:-15000}"
  KIBANA_PORT="${KIBANA_PORT:-5601}"

  if is_true "$TAZAMA_ENABLE_UI"; then
    TAZAMA_ENABLE_AUTH=0
    TAZAMA_ENABLE_RELAY=0
  fi

  if [ "$TAZAMA_STACK_TYPE" = "multitenant" ]; then
    TAZAMA_ENABLE_AUTH=1
    TAZAMA_ENABLE_RELAY=1
  fi

  export TAZAMA_STACK_TYPE TAZAMA_VERSION TAZAMA_PROJECT_NAME
  export TAZAMA_ENABLE_AUTH TAZAMA_ENABLE_RELAY TAZAMA_ENABLE_BASIC_LOGS TAZAMA_ENABLE_UI
  export TAZAMA_ENABLE_NATS_UTILS TAZAMA_ENABLE_BATCH_PPA TAZAMA_ENABLE_PGADMIN TAZAMA_ENABLE_HASURA
  export TMS_PORT ADMIN_PORT POSTGRES_PORT PGADMIN_PORT APMSERVER_PORT ES_PORT EVENT_SIDECAR_PORT KIBANA_PORT
}

build_tazama_compose_files() {
  TAZAMA_COMPOSE_FILES=(
    "$TAZAMA_STACK_ROOT/docker-compose.base.infrastructure.yaml"
    "$TAZAMA_STACK_ROOT/docker-compose.base.override.yaml"
  )

  case "$TAZAMA_STACK_TYPE" in
    public-github)
      TAZAMA_COMPOSE_FILES+=(
        "$TAZAMA_STACK_ROOT/docker-compose.dev.cfg.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.dev.core.yaml"
      )
      ;;
    public-dockerhub)
      TAZAMA_COMPOSE_FILES+=(
        "$TAZAMA_STACK_ROOT/docker-compose.hub.cfg.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.hub.core.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.hub.rules.yaml"
      )
      ;;
    full-dockerhub)
      TAZAMA_COMPOSE_FILES+=(
        "$TAZAMA_STACK_ROOT/docker-compose.full.cfg.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.hub.core.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.full.rules.yaml"
      )
      ;;
    multitenant)
      TAZAMA_COMPOSE_FILES+=(
        "$TAZAMA_STACK_ROOT/docker-compose.base.auth.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.multitenant.cfg.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.hub.core.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.hub.rules.yaml"
        "$TAZAMA_STACK_ROOT/docker-compose.multitenant.relay.yaml"
      )
      ;;
    *)
      echo "Unsupported Tazama stack type: $TAZAMA_STACK_TYPE" >&2
      exit 1
      ;;
  esac

  if [ "$TAZAMA_STACK_TYPE" != "multitenant" ]; then
    if is_true "$TAZAMA_ENABLE_AUTH"; then
      TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.base.auth.yaml")
      if [ "$TAZAMA_STACK_TYPE" = "public-github" ]; then
        TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.dev.auth.yaml")
      fi
    fi

    if is_true "$TAZAMA_ENABLE_RELAY"; then
      case "$TAZAMA_STACK_TYPE" in
        public-github)
          TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.dev.relay.yaml")
          ;;
        public-dockerhub|full-dockerhub)
          TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.hub.relay.yaml")
          ;;
      esac
    fi
  fi

  if is_true "$TAZAMA_ENABLE_BASIC_LOGS"; then
    if [ "$TAZAMA_STACK_TYPE" = "public-github" ]; then
      TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.dev.logs.base.yaml")
    else
      TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.hub.logs.base.yaml")
    fi
  fi

  is_true "$TAZAMA_ENABLE_UI" && TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.hub.ui.yaml")
  is_true "$TAZAMA_ENABLE_NATS_UTILS" && TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.utils.nats-utils.yaml")
  is_true "$TAZAMA_ENABLE_BATCH_PPA" && TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.utils.batch-ppa.yaml")
  is_true "$TAZAMA_ENABLE_PGADMIN" && TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.utils.pgadmin.yaml")
  is_true "$TAZAMA_ENABLE_HASURA" && TAZAMA_COMPOSE_FILES+=("$TAZAMA_STACK_ROOT/docker-compose.utils.hasura.yaml")

  export TAZAMA_COMPOSE_FILES
}

resolve_tazama_compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    TAZAMA_COMPOSE_CMD=(docker compose)
    return 0
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    TAZAMA_COMPOSE_CMD=(docker-compose)
    return 0
  fi

  echo "Tazama needs either 'docker compose' or 'docker-compose' available on PATH." >&2
  echo "This machine currently has Docker but no compose frontend installed." >&2
  exit 1
}

build_tazama_compose_args() {
  TAZAMA_COMPOSE_ARGS=()
  local compose_file
  for compose_file in "${TAZAMA_COMPOSE_FILES[@]}"; do
    TAZAMA_COMPOSE_ARGS+=(-f "$compose_file")
  done
  export TAZAMA_COMPOSE_ARGS
}

print_tazama_compose_command() {
  local cmd_name="docker compose"
  local compose_file

  if declare -p TAZAMA_COMPOSE_CMD >/dev/null 2>&1 && [ "${#TAZAMA_COMPOSE_CMD[@]}" -gt 0 ]; then
    cmd_name="${TAZAMA_COMPOSE_CMD[*]}"
  fi

  printf "%s" "$cmd_name"
  for compose_file in "${TAZAMA_COMPOSE_FILES[@]}"; do
    printf " -f %q" "$compose_file"
  done
  printf " -p %q" "$TAZAMA_PROJECT_NAME"
}

run_tazama_compose() {
  "${TAZAMA_COMPOSE_CMD[@]}" "${TAZAMA_COMPOSE_ARGS[@]}" -p "$TAZAMA_PROJECT_NAME" "$@"
}

print_tazama_summary() {
  echo "Tazama stack root: $TAZAMA_STACK_ROOT"
  echo "Tazama env file: $TAZAMA_ENV_FILE"
  echo "Tazama stack type: $TAZAMA_STACK_TYPE"
  echo "Tazama version: $TAZAMA_VERSION"
  echo "Tazama project: $TAZAMA_PROJECT_NAME"
  echo "Compose files:"
  printf '  - %s\n' "${TAZAMA_COMPOSE_FILES[@]}"
}

tazama_init() {
  find_tazama_stack_root
  load_tazama_env
  normalize_tazama_defaults
  build_tazama_compose_files
  build_tazama_compose_args
}
