#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

WALLET_STACK="${WALLET_STACK:-pivotal}"
case "$WALLET_STACK" in
  pivotal)
    ENV_FILE="$CONF_DIR/wallet2-pivotal.env"
    ;;
  core|core-connector)
    ENV_FILE="$CONF_DIR/wallet2.env"
    ;;
  *)
    echo "Unsupported WALLET_STACK: $WALLET_STACK (expected pivotal or core)" >&2
    exit 1
    ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing wallet2 env file: $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [ "$WALLET_STACK" != "pivotal" ]; then
  WALLET2_CURRENCY="$CURRENCY"
  WALLET2_INITIAL_NET_DEBIT_CAP="$INITIAL_NET_DEBIT_CAP"
  WALLET2_INITIAL_FUNDS="$INITIAL_FUNDS"
fi

API_BASE="http://127.0.0.1:3001"
SOURCE_HEADER="wallet2-setup"
PARTICIPANT_NAME="${CONNECTOR_ID}"

json_get() {
  local path="$1"
  curl -fsS \
    -H "FSPIOP-Source: $SOURCE_HEADER" \
    "$API_BASE$path"
}

api_post() {
  local path="$1"
  local body="$2"
  local status
  status="$(
    curl -sS \
      -o /tmp/wallet2-api-response.json \
      -w '%{http_code}' \
      -X POST \
      -H 'Content-Type: application/json' \
      -H "FSPIOP-Source: $SOURCE_HEADER" \
      "$API_BASE$path" \
      --data-raw "$body"
  )"

  if [[ "$status" =~ ^2 ]]; then
    return 0
  fi

  cat /tmp/wallet2-api-response.json >&2
  echo >&2
  echo "POST $path failed with status $status" >&2
  return 1
}

api_get_status() {
  local path="$1"
  curl -sS -o /tmp/wallet2-api-response.json -w '%{http_code}' \
    -H "FSPIOP-Source: $SOURCE_HEADER" \
    "$API_BASE$path"
}

ensure_hub_account() {
  local account_type="$1"
  local accounts_json
  accounts_json="$(json_get "/participants/Hub/accounts")"
  if echo "$accounts_json" | node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const found = Array.isArray(data) && data.some((entry) => entry.ledgerAccountType === '$account_type' && entry.currency === '$WALLET2_CURRENCY');
    process.exit(found ? 0 : 1);
  "; then
    return
  fi

  api_post "/participants/Hub/accounts" "{
    \"currency\": \"$WALLET2_CURRENCY\",
    \"type\": \"$account_type\"
  }"
}

ensure_settlement_model() {
  local models_json
  models_json="$(json_get "/settlementModels")"
  if echo "$models_json" | node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const found = Array.isArray(data) && data.some((entry) => entry.name === 'DEFERREDNET' && entry.currency === '$WALLET2_CURRENCY');
    process.exit(found ? 0 : 1);
  "; then
    return
  fi

  api_post "/settlementModels" "{
    \"name\": \"DEFERREDNET\",
    \"settlementGranularity\": \"NET\",
    \"settlementInterchange\": \"MULTILATERAL\",
    \"settlementDelay\": \"DEFERRED\",
    \"requireLiquidityCheck\": true,
    \"ledgerAccountType\": \"POSITION\",
    \"autoPositionReset\": true,
    \"currency\": \"$WALLET2_CURRENCY\",
    \"settlementAccountType\": \"SETTLEMENT\"
  }"
}

ensure_participant() {
  local status
  status="$(api_get_status "/participants/$PARTICIPANT_NAME")"
  if [ "$status" = "200" ]; then
    return
  fi

  api_post "/participants" "{
    \"name\": \"$PARTICIPANT_NAME\",
    \"currency\": \"$WALLET2_CURRENCY\",
    \"isProxy\": false
  }"
}

ensure_initial_position_and_limits() {
  local limits_json
  limits_json="$(json_get "/participants/$PARTICIPANT_NAME/limits")"
  if echo "$limits_json" | node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const found = Array.isArray(data) && data.some((entry) => entry.currency === '$WALLET2_CURRENCY' && entry.limit?.type === 'NET_DEBIT_CAP');
    process.exit(found ? 0 : 1);
  "; then
    return
  fi

  api_post "/participants/$PARTICIPANT_NAME/initialPositionAndLimits" "{
    \"currency\": \"$WALLET2_CURRENCY\",
    \"limit\": {
      \"type\": \"NET_DEBIT_CAP\",
      \"value\": $WALLET2_INITIAL_NET_DEBIT_CAP
    },
    \"initialPosition\": 0
  }"
}

get_settlement_account_id() {
  json_get "/participants/$PARTICIPANT_NAME/accounts" | node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const account = Array.isArray(data)
      ? data.find((entry) => entry.ledgerAccountType === 'SETTLEMENT' && entry.currency === '$WALLET2_CURRENCY')
      : undefined;
    if (!account) process.exit(1);
    process.stdout.write(String(account.id));
  "
}

settlement_balance_is_funded() {
  json_get "/participants/$PARTICIPANT_NAME/accounts" | node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const account = Array.isArray(data)
      ? data.find((entry) => entry.ledgerAccountType === 'SETTLEMENT' && entry.currency === '$WALLET2_CURRENCY')
      : undefined;
    const value = BigInt(String(account?.value ?? '0'));
    const threshold = BigInt('$WALLET2_INITIAL_FUNDS');
    const funded = value >= threshold || value <= -threshold;
    process.exit(funded ? 0 : 1);
  "
}

ensure_funds() {
  if settlement_balance_is_funded; then
    return
  fi

  local account_id
  local transfer_id
  account_id="$(get_settlement_account_id)"
  transfer_id="$(node -e "console.log(require('node:crypto').randomUUID())")"

  api_post "/participants/$PARTICIPANT_NAME/accounts/$account_id" "{
    \"transferId\": \"$transfer_id\",
    \"externalReference\": \"wallet2-bootstrap\",
    \"action\": \"recordFundsIn\",
    \"reason\": \"wallet2-bootstrap\",
    \"amount\": {
      \"amount\": \"$WALLET2_INITIAL_FUNDS\",
      \"currency\": \"$WALLET2_CURRENCY\"
    }
  }"
}

ensure_endpoint() {
  local endpoint_type="$1"
  local endpoint_value="$2"
  local endpoints_json
  endpoints_json="$(json_get "/participants/$PARTICIPANT_NAME/endpoints")"

  if echo "$endpoints_json" | node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const found = Array.isArray(data) && data.some((entry) => entry.type === '$endpoint_type' && entry.value === '$endpoint_value');
    process.exit(found ? 0 : 1);
  "; then
    return
  fi

  api_post "/participants/$PARTICIPANT_NAME/endpoints" "{
    \"type\": \"$endpoint_type\",
    \"value\": \"$endpoint_value\"
  }"
}

ensure_hub_account HUB_RECONCILIATION
ensure_hub_account HUB_MULTILATERAL_SETTLEMENT
ensure_settlement_model
ensure_participant
ensure_initial_position_and_limits
ensure_funds

ensure_endpoint FSPIOP_CALLBACK_URL_PARTIES_GET "http://127.0.0.1:${WEB_INBOUND_PORT}/parties/{{partyIdType}}/{{partyIdentifier}}"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTIES_SUB_ID_GET "http://127.0.0.1:${WEB_INBOUND_PORT}/parties/{{partyIdType}}/{{partyIdentifier}}/{{partySubIdOrType}}"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTIES_PUT "http://127.0.0.1:${WEB_INBOUND_PORT}/parties/{{partyIdType}}/{{partyIdentifier}}"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTIES_SUB_ID_PUT "http://127.0.0.1:${WEB_INBOUND_PORT}/parties/{{partyIdType}}/{{partyIdentifier}}/{{partySubIdOrType}}"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTIES_PUT_ERROR "http://127.0.0.1:${WEB_INBOUND_PORT}/parties/{{partyIdType}}/{{partyIdentifier}}/error"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTIES_SUB_ID_PUT_ERROR "http://127.0.0.1:${WEB_INBOUND_PORT}/parties/{{partyIdType}}/{{partyIdentifier}}/{{partySubIdOrType}}/error"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTICIPANT_PUT "http://127.0.0.1:${WEB_INBOUND_PORT}/participants/{{partyIdType}}/{{partyIdentifier}}"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTICIPANT_SUB_ID_PUT "http://127.0.0.1:${WEB_INBOUND_PORT}/participants/{{partyIdType}}/{{partyIdentifier}}/{{partySubIdOrType}}"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTICIPANT_PUT_ERROR "http://127.0.0.1:${WEB_INBOUND_PORT}/participants/{{partyIdType}}/{{partyIdentifier}}/error"
ensure_endpoint FSPIOP_CALLBACK_URL_PARTICIPANT_SUB_ID_PUT_ERROR "http://127.0.0.1:${WEB_INBOUND_PORT}/participants/{{partyIdType}}/{{partyIdentifier}}/{{partySubIdOrType}}/error"
ensure_endpoint FSPIOP_CALLBACK_URL_QUOTES "http://127.0.0.1:${WEB_INBOUND_PORT}"
ensure_endpoint FSPIOP_CALLBACK_URL_TRANSFER_POST "http://127.0.0.1:${WEB_INBOUND_PORT}/transfers"
ensure_endpoint FSPIOP_CALLBACK_URL_TRANSFER_PUT "http://127.0.0.1:${WEB_INBOUND_PORT}/transfers/{{transferId}}"
ensure_endpoint FSPIOP_CALLBACK_URL_TRANSFER_ERROR "http://127.0.0.1:${WEB_INBOUND_PORT}/transfers/{{transferId}}/error"
