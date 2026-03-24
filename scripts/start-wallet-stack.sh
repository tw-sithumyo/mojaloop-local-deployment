#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wallet-stack-common.sh"

WALLET1_ENV_FILE="$CONF_DIR/wallet1.env"
WALLET2_ENV_FILE="$CONF_DIR/wallet2.env"
WALLET1_SDK_ENV_FILE="$CONF_DIR/wallet1-sdk.env"
WALLET2_SDK_ENV_FILE="$CONF_DIR/wallet2-sdk.env"
WALLET1_CC_ENV_FILE="$CONF_DIR/wallet1-cc-service.env"
WALLET2_CC_ENV_FILE="$CONF_DIR/wallet2-cc-service.env"

for required_file in \
  "$WALLET1_ENV_FILE" \
  "$WALLET2_ENV_FILE" \
  "$WALLET1_SDK_ENV_FILE" \
  "$WALLET2_SDK_ENV_FILE" \
  "$WALLET1_CC_ENV_FILE" \
  "$WALLET2_CC_ENV_FILE"; do
  if [ ! -f "$required_file" ]; then
    echo "Missing wallet config: $required_file" >&2
    exit 1
  fi
done

require_listening_port valkey 6379
require_listening_port ml-api-adapter 3000
require_listening_port central-ledger 3001
require_listening_port als-api 4002
require_listening_port quoting-api 3002

JDK_HOME="$(resolve_jdk_home)"
MVN_CMD="$(resolve_maven_cmd)"

ensure_sdk_dependencies
ensure_cc_built "$JDK_HOME" "$MVN_CMD"

start_wallet_backend() {
  local env_file="$1"
  local wallet_name
  local backend_port
  local party_id
  local display_name
  local first_name
  local last_name
  local currency
  local fee_amount
  local starting_balance

  set -a
  source "$env_file"
  set +a

  wallet_name="$CONNECTOR_ID"
  backend_port="$WALLET_BACKEND_PORT"
  party_id="$PARTY_ID"
  display_name="$DISPLAY_NAME"
  first_name="$FIRST_NAME"
  last_name="$LAST_NAME"
  currency="$CURRENCY"
  fee_amount="$FEE_AMOUNT"
  starting_balance="$STARTING_BALANCE"

  local script
  printf -v script \
    'exec env PORT=%q WALLET_LABEL=%q PARTY_ID=%q DISPLAY_NAME=%q FIRST_NAME=%q LAST_NAME=%q SUPPORTED_CURRENCIES=%q FEE_AMOUNT=%q STARTING_BALANCE=%q node %q' \
    "$backend_port" \
    "$wallet_name" \
    "$party_id" \
    "$display_name" \
    "$first_name" \
    "$last_name" \
    "$currency" \
    "$fee_amount" \
    "$starting_balance" \
    "$LOCAL_HOME/mocks/thitsawallet-backend.mjs"

  start_shell_process "${wallet_name}-backend" "$ROOT_DIR" "$backend_port" "$script"
}

start_wallet_sdk() {
  local wallet_env_file="$1"
  local sdk_env_file="$2"
  local wallet_name
  local inbound_port
  local outbound_port

  set -a
  source "$wallet_env_file"
  set +a

  wallet_name="$CONNECTOR_ID"
  inbound_port="$WEB_INBOUND_PORT"
  outbound_port="$WEB_OUTBOUND_PORT"

  local sdk_env_file_q script
  printf -v sdk_env_file_q '%q' "$sdk_env_file"
  printf -v script 'set -a; source %s; set +a; exec corepack yarn nx run modules-api-svc:start' "$sdk_env_file_q"

  start_shell_process "${wallet_name}-sdk" "$SDK_REPO" "$outbound_port" "$script"
  wait_http "${wallet_name}-sdk-outbound" "$outbound_port" /
  wait_port "${wallet_name}-sdk-inbound" "$inbound_port"
}

start_wallet_cc() {
  local wallet_env_file="$1"
  local cc_env_file="$2"
  local wallet_name
  local cc_port

  set -a
  source "$wallet_env_file"
  source "$cc_env_file"
  set +a

  wallet_name="$CONNECTOR_ID"
  cc_port="$WALLET_CC_PORT"

  local java_bin classpath script
  java_bin="$JDK_HOME/bin/java"
  classpath="$CC_JAR:$CC_LIB_DIR/*"

  printf -v script \
    'exec env JAVA_HOME=%q PATH=%q %q -Dserver.port=%q -DoutboundEndpoint=%q -Dbackend.endpoint=%q -Ddfsp.locale=%q -Dis.prefix=%q -Dproject=%q -DredisUrl=%q -DcacheLifeTime=%q -DpublicKey=%q -DsupportedCurrencies=%q -DdecimalPlaces=%q -DprefixOracleEndpoint=%q -DfeeEngineEndpoint=%q -cp %q %q' \
    "$JDK_HOME" \
    "$JDK_HOME/bin:$PATH" \
    "$java_bin" \
    "$cc_port" \
    "$MLCONN_OUTBOUND_ENDPOINT" \
    "$BACKEND_ENDPOINT" \
    "$DFSP_LOCALE" \
    "$IS_PREFIX" \
    "$PROJECT" \
    "$REDIS_URL" \
    "$CACHE_LIFE_TIME" \
    "$PUBLIC_KEY" \
    "$SUPPORTED_CURRENCIES" \
    "$DECIMAL_PLACES" \
    "$PREFIX_ORACLE_ENDPOINT" \
    "$FEE_ENGINE_ENDPOINT" \
    "$classpath" \
    "$CC_MAIN_CLASS"

  start_shell_process "${wallet_name}-cc" "$CC_REPO" "$cc_port" "$script"
}

start_wallet_backend "$WALLET1_ENV_FILE"
start_wallet_backend "$WALLET2_ENV_FILE"
wait_http wallet1-backend 3403 /health
wait_http wallet2-backend 3404 /health

start_wallet_sdk "$WALLET1_ENV_FILE" "$WALLET1_SDK_ENV_FILE"
start_wallet_sdk "$WALLET2_ENV_FILE" "$WALLET2_SDK_ENV_FILE"

start_wallet_cc "$WALLET1_ENV_FILE" "$WALLET1_CC_ENV_FILE"
start_wallet_cc "$WALLET2_ENV_FILE" "$WALLET2_CC_ENV_FILE"
wait_port wallet1-cc 3303
wait_port wallet2-cc 3304
