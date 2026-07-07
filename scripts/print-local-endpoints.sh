#!/usr/bin/env bash

if [ -z "${LOCAL_HOME:-}" ]; then
  # shellcheck source=../env.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"
fi

print_local_load_env_file() {
  local env_file="$1"

  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

print_local_load_pivotal_env() {
  if [ -f "$CONF_DIR/wallet1-pivotal.env" ]; then
    print_local_load_env_file "$CONF_DIR/wallet1-pivotal.env"
  elif [ -f "$CONF_DIR/wallet2-pivotal.env" ]; then
    print_local_load_env_file "$CONF_DIR/wallet2-pivotal.env"
  fi

  print_local_load_env_file "$PIVOTAL_HOME/packages/apps/web-pivotal/.env"
  print_local_load_env_file "$PIVOTAL_HOME/packages/portal/.env"
}

print_local_section() {
  echo
  echo "$1:"
}

print_local_endpoint() {
  local label="$1"
  local value="$2"

  printf '  %-30s %s\n' "${label}:" "$value"
}

print_local_infra_endpoints() {
  print_local_section "Infrastructure endpoints"
  print_local_endpoint "MariaDB" "127.0.0.1:3306"
  print_local_endpoint "Valkey/Redis" "redis://127.0.0.1:6379"
  print_local_endpoint "Kafka broker" "127.0.0.1:9092"
  print_local_endpoint "Kafka controller" "127.0.0.1:9093"
}

print_local_nats_endpoints() {
  print_local_section "NATS endpoints"
  print_local_endpoint "Client" "nats://127.0.0.1:4222"
  print_local_endpoint "Monitoring" "http://127.0.0.1:8222"
  print_local_endpoint "Health" "http://127.0.0.1:8222/healthz"
}

print_local_core_endpoints() {
  print_local_section "Mojaloop core endpoints"
  print_local_endpoint "ML API Adapter" "http://127.0.0.1:3000"
  print_local_endpoint "Central Ledger API" "http://127.0.0.1:3001"
  print_local_endpoint "Central Ledger handlers" "http://127.0.0.1:3011"
  print_local_endpoint "Quoting API" "http://127.0.0.1:3002"
  print_local_endpoint "Quoting handlers" "http://127.0.0.1:3103"
  print_local_endpoint "Account Lookup Admin" "http://127.0.0.1:4001"
  print_local_endpoint "Account Lookup API" "http://127.0.0.1:4002"
  print_local_endpoint "Account Lookup handlers" "http://127.0.0.1:4003"
  print_local_endpoint "Central Settlement API" "http://127.0.0.1:3007"
}

print_local_pivotal_endpoints() {
  print_local_load_pivotal_env

  local web_outbound_port="${WEB_OUTBOUND_PORT:-3200}"
  local web_inbound_port="${WEB_INBOUND_PORT:-3201}"
  local web_pivotal_port="${WEB_PIVOTAL_PORT:-3202}"
  local portal_port="${PIVOTAL_PORTAL_PORT:-4173}"
  local api_base_url="${VITE_WEB_PIVOTAL_API_BASE_URL:-http://localhost:${web_pivotal_port}}"

  print_local_section "Pivotal endpoints"
  print_local_endpoint "Web Outbound" "http://127.0.0.1:${web_outbound_port}"
  print_local_endpoint "Web Inbound" "http://127.0.0.1:${web_inbound_port}"
  print_local_endpoint "Portal API" "http://127.0.0.1:${web_pivotal_port}"
  print_local_endpoint "Portal API health" "http://127.0.0.1:${web_pivotal_port}/healthz"
  print_local_endpoint "Portal UI" "http://127.0.0.1:${portal_port}"
  print_local_endpoint "Portal UI API base" "$api_base_url"
  print_local_endpoint "App auditor" "background process (no HTTP port)"
  print_local_endpoint "Report worker" "background process (no HTTP port)"
}

print_local_report_worker_endpoint() {
  print_local_section "Pivotal report worker"
  print_local_endpoint "Worker" "background process (no HTTP port)"
  print_local_endpoint "Log" "$LOG_DIR/pivotal-report-worker.log"
}

print_local_app_auditor_endpoint() {
  print_local_section "Pivotal app auditor"
  print_local_endpoint "Auditor" "background process (no HTTP port)"
  print_local_endpoint "Log" "$LOG_DIR/pivotal-app-auditor.log"
}

print_local_demowallet_endpoint() {
  local wallet="$1"
  local port
  local url

  case "$wallet" in
    wallet1)
      port="8081"
      ;;
    wallet2)
      port="8082"
      ;;
    *)
      echo "Unknown wallet for endpoint summary: $wallet" >&2
      return 1
      ;;
  esac

  print_local_load_env_file "$CONF_DIR/${wallet}-pivotal.env"
  url="${DEMOWALLET_URL:-http://127.0.0.1:${port}}"

  print_local_section "${wallet} DemoWallet endpoints"
  print_local_endpoint "API" "$url"
  print_local_endpoint "Heartbeat" "${url%/}/public/heart_beat"
}

print_local_connector_endpoint() {
  local wallet="$1"
  local env_file="$CONF_DIR/${wallet}-pivotal.env"

  print_local_load_env_file "$env_file"

  print_local_section "${wallet} Pivotal connector"
  print_local_endpoint "Connector" "background process (no HTTP port)"
  print_local_endpoint "Connector ID" "${CONNECTOR_ID:-$wallet}"
  print_local_endpoint "Backend API" "${BACKEND_API_URL:-${DEMOWALLET_URL:-not configured}}"
  print_local_endpoint "NATS" "${NATS_URL:-nats://127.0.0.1:4222}"
  print_local_endpoint "Parties URL" "${FSPIOP_PARTIES_URL:-http://127.0.0.1:4002}"
  print_local_endpoint "Quotes URL" "${FSPIOP_QUOTES_URL:-http://127.0.0.1:3002}"
  print_local_endpoint "Transfers URL" "${FSPIOP_TRANSFERS_URL:-http://127.0.0.1:3000}"
  print_local_endpoint "Log" "$LOG_DIR/${wallet}-pivotal-connector.log"
}

print_local_wallet_endpoint_summary() {
  local wallet="$1"
  local id_type=""
  local id_value=""
  local currency=""

  print_local_demowallet_endpoint "$wallet"
  print_local_connector_endpoint "$wallet"

  case "$wallet" in
    wallet1)
      id_type="${WALLET1_PARTY_ID_TYPE:-}"
      id_value="${WALLET1_PARTY_ID:-}"
      currency="${WALLET1_CURRENCY:-}"
      ;;
    wallet2)
      id_type="${WALLET2_PARTY_ID_TYPE:-}"
      id_value="${WALLET2_PARTY_ID:-}"
      currency="${WALLET2_CURRENCY:-}"
      ;;
  esac

  if [ -n "$id_type$id_value$currency" ]; then
    print_local_section "${wallet} test party"
    print_local_endpoint "Party" "${id_type:-unknown} ${id_value:-unknown}"
    print_local_endpoint "Currency" "${currency:-unknown}"
  fi
}

print_local_monitor_endpoint() {
  local ui_host="${LOCAL_UI_HOST:-127.0.0.1}"
  local ui_port="${LOCAL_UI_PORT:-3400}"

  print_local_section "Local monitor endpoint"
  print_local_endpoint "UI" "http://${ui_host}:${ui_port}"
  print_local_endpoint "Status API" "http://${ui_host}:${ui_port}/api/status"
}

print_local_reporting_endpoints() {
  print_local_load_env_file "$CONF_DIR/reporting-aggregator.env"

  local mongo_host="${REPORTING_MONGO_DB_HOST:-${REPORTING_MONGO_HOST:-127.0.0.1}}"
  local mongo_port="${REPORTING_MONGO_DB_PORT:-${REPORTING_MONGO_PORT:-27017}}"
  local mongo_db="${REPORTING_MONGO_DB_DATABASE:-${REPORTING_MONGO_DB:-reporting}}"

  print_local_section "Reporting endpoints"
  print_local_endpoint "Aggregator" "background process (no HTTP port)"
  print_local_endpoint "MongoDB" "mongodb://${mongo_host}:${mongo_port}/${mongo_db}"
  print_local_endpoint "Log" "$LOG_DIR/reporting-aggregator.log"
}

print_local_operation_portal_endpoints() {
  print_local_load_env_file "$CONF_DIR/operation-portal.env"

  local op_port="${OPERATION_PORTAL_PORT:-8003}"
  local vault_addr="${OPERATION_PORTAL_VAULT_ADDR:-http://127.0.0.1:8200}"
  local frontend_url="${OPERATION_PORTAL_FRONTEND_ENDPOINT:-http://127.0.0.1:4180}"

  print_local_section "Operation Portal endpoints"
  print_local_endpoint "API" "http://127.0.0.1:${op_port}"
  print_local_endpoint "Health" "http://127.0.0.1:${op_port}/actuator/health"
  print_local_endpoint "Frontend URL config" "$frontend_url"
  print_local_endpoint "Vault" "$vault_addr"
}

print_local_tazama_endpoints() {
  print_local_load_env_file "$CONF_DIR/tazama.env"

  print_local_section "Tazama endpoints"
  print_local_endpoint "TMS Swagger" "http://127.0.0.1:${TMS_PORT:-5000}/documentation"
  print_local_endpoint "Admin Swagger" "http://127.0.0.1:${ADMIN_PORT:-5100}/documentation"

  if [ "${TAZAMA_ENABLE_UI:-0}" = "1" ]; then
    print_local_endpoint "Demo UI" "http://127.0.0.1:3001"
  fi
  if [ "${TAZAMA_ENABLE_PGADMIN:-0}" = "1" ]; then
    print_local_endpoint "pgAdmin" "http://127.0.0.1:${PGADMIN_PORT:-15050}"
  fi
  if [ "${TAZAMA_ENABLE_HASURA:-0}" = "1" ]; then
    print_local_endpoint "Hasura" "http://127.0.0.1:6100"
  fi
}

print_local_ppa_endpoints() {
  print_local_load_env_file "$CONF_DIR/tazama.env"
  print_local_load_env_file "$CONF_DIR/ppa.env"

  local ppa_host="${PPA_HOST:-127.0.0.1}"
  local ppa_port="${PPA_PORT:-3500}"

  print_local_section "PPA endpoints"
  print_local_endpoint "API" "http://${ppa_host}:${ppa_port}"
  print_local_endpoint "Health" "http://${ppa_host}:${ppa_port}/health"
  print_local_endpoint "TMS endpoint" "${TMS_ENDPOINT:-http://127.0.0.1:${TMS_PORT:-5000}}"
  print_local_endpoint "Kafka topic" "${KAFKA_TOPIC_TO_CONSUME:-not configured}"
}

print_local_component_selected() {
  local wanted="$1"
  shift
  local item

  for item in "$@"; do
    if [ "$item" = "$wanted" ]; then
      return 0
    fi
  done

  return 1
}

print_local_start_all_summary() {
  local components=("$@")

  echo
  echo "Local stack endpoints"
  echo "Selected components: ${components[*]}"

  if print_local_component_selected infra "${components[@]}"; then
    print_local_infra_endpoints
  fi

  if print_local_component_selected core "${components[@]}"; then
    print_local_core_endpoints
  fi

  if print_local_component_selected wallet1 "${components[@]}" || print_local_component_selected wallet2 "${components[@]}"; then
    print_local_nats_endpoints
    print_local_pivotal_endpoints
  fi

  if print_local_component_selected wallet1 "${components[@]}"; then
    print_local_wallet_endpoint_summary wallet1
  fi

  if print_local_component_selected wallet2 "${components[@]}"; then
    print_local_wallet_endpoint_summary wallet2
  fi

  if print_local_component_selected ui "${components[@]}"; then
    print_local_monitor_endpoint
  fi

  if print_local_component_selected reporting "${components[@]}"; then
    print_local_reporting_endpoints
  fi

  if print_local_component_selected operation-portal "${components[@]}"; then
    print_local_operation_portal_endpoints
  fi

  if print_local_component_selected tazama "${components[@]}"; then
    print_local_tazama_endpoints
  fi

  if print_local_component_selected ppa "${components[@]}"; then
    print_local_ppa_endpoints
  fi
}
