#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

WALLET1_ENV_FILE="$CONF_DIR/wallet1-pivotal.env"
WALLET2_ENV_FILE="$CONF_DIR/wallet2-pivotal.env"

if [ ! -f "$WALLET1_ENV_FILE" ]; then
  echo "Missing wallet1 env file: $WALLET1_ENV_FILE" >&2
  exit 1
fi

if [ ! -f "$WALLET2_ENV_FILE" ]; then
  echo "Missing wallet2 env file: $WALLET2_ENV_FILE" >&2
  exit 1
fi

set -a
source "$WALLET1_ENV_FILE"
set +a

WALLET1_CONNECTOR_ID="$CONNECTOR_ID"
WALLET1_OUTBOUND_PORT="$WEB_OUTBOUND_PORT"
WALLET1_PARTY_ID_TYPE_VALUE="$WALLET1_PARTY_ID_TYPE"
WALLET1_PARTY_ID_VALUE="$WALLET1_PARTY_ID"
WALLET1_CURRENCY_VALUE="$WALLET1_CURRENCY"

set -a
source "$WALLET2_ENV_FILE"
set +a

WALLET2_CONNECTOR_ID="$CONNECTOR_ID"
WALLET2_INBOUND_PORT="$WEB_INBOUND_PORT"
WALLET2_PARTY_ID_TYPE_VALUE="$WALLET2_PARTY_ID_TYPE"
WALLET2_PARTY_ID_VALUE="$WALLET2_PARTY_ID"

REPRO_PROXY_PORT="${REPRO_PROXY_PORT:-3299}"
REPRO_PAYEE_DELAY_MS="${REPRO_PAYEE_DELAY_MS:-17000}"
REPRO_TRANSFER_EXPIRY_SECONDS="${REPRO_TRANSFER_EXPIRY_SECONDS:-5}"
REPRO_POST_TRANSFER_WAIT_SECONDS="${REPRO_POST_TRANSFER_WAIT_SECONDS:-6}"

AUTH_HEADER='Bearer a.b.c'
API_BASE="http://127.0.0.1:3001"
OUTBOUND_BASE="http://127.0.0.1:${WALLET1_OUTBOUND_PORT}"
PAYEE_ORIGINAL_TRANSFER_ENDPOINT="http://127.0.0.1:${WALLET2_INBOUND_PORT}/transfers"
PAYEE_PROXY_TRANSFER_ENDPOINT="http://127.0.0.1:${REPRO_PROXY_PORT}/transfers"
PAYEE_PROXY_TARGET="http://127.0.0.1:${WALLET2_INBOUND_PORT}"

HTTP_STATUS=''
HTTP_BODY=''
TRANSFER_ID=''
PROXY_WAS_RUNNING=0
ENDPOINT_UPDATED=0

need_port() {
  local name="$1"
  local port="$2"

  if ! ss -ltn | rg -q "[:.]$port\\b"; then
    echo "$name is not listening on port $port" >&2
    echo "Run local/scripts/start-mojaloop-core-services.sh plus wallet setup/start scripts before this repro." >&2
    exit 1
  fi
}

http_post_json() {
  local url="$1"
  local body="$2"
  local source_header="$3"
  local body_file

  body_file="$(mktemp)"
  HTTP_STATUS="$(
    curl -sS \
      -o "$body_file" \
      -w '%{http_code}' \
      -X POST \
      -H 'Content-Type: application/json' \
      -H "FSPIOP-Source: $source_header" \
      -H "fspiop-source: $source_header" \
      -H "authorization: ${AUTH_HEADER}" \
      "$url" \
      --data-raw "$body" || true
  )"
  HTTP_BODY="$(cat "$body_file")"
  rm -f "$body_file"
}

require_2xx() {
  local label="$1"

  if [[ "$HTTP_STATUS" =~ ^2 ]]; then
    return
  fi

  echo "$label failed with HTTP $HTTP_STATUS" >&2
  echo "$HTTP_BODY" >&2
  exit 1
}

set_wallet2_transfer_endpoint() {
  local endpoint_value="$1"

  http_post_json "$API_BASE/participants/$WALLET2_CONNECTOR_ID/endpoints" "{
    \"type\": \"FSPIOP_CALLBACK_URL_TRANSFER_POST\",
    \"value\": \"$endpoint_value\"
  }" "notification-timeout-repro"
  require_2xx "Updating wallet2 transfer endpoint"
  ENDPOINT_UPDATED=1
}

restore_wallet2_transfer_endpoint() {
  if [ "$ENDPOINT_UPDATED" != "1" ]; then
    return
  fi

  http_post_json "$API_BASE/participants/$WALLET2_CONNECTOR_ID/endpoints" "{
    \"type\": \"FSPIOP_CALLBACK_URL_TRANSFER_POST\",
    \"value\": \"$PAYEE_ORIGINAL_TRANSFER_ENDPOINT\"
  }" "notification-timeout-repro" || true
}

cleanup() {
  restore_wallet2_transfer_endpoint || true
  if [ "$PROXY_WAS_RUNNING" = "0" ]; then
    DELAY_PROXY_PORT="$REPRO_PROXY_PORT" "$LOCAL_HOME/scripts/stop-delay-proxy.sh" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

need_port central-ledger-api 3001
need_port central-ledger-handlers 3011
need_port ml-api-adapter-api 3000
need_port ml-api-adapter-handler 3010
need_port wallet-outbound "$WALLET1_OUTBOUND_PORT"
need_port wallet-inbound "$WALLET2_INBOUND_PORT"

if ss -ltn | rg -q "[:.]$REPRO_PROXY_PORT\\b"; then
  PROXY_WAS_RUNNING=1
fi

DELAY_PROXY_PORT="$REPRO_PROXY_PORT" \
DELAY_PROXY_TARGET="$PAYEE_PROXY_TARGET" \
DELAY_PROXY_DELAY_MS="$REPRO_PAYEE_DELAY_MS" \
  "$LOCAL_HOME/scripts/start-delay-proxy.sh"

set_wallet2_transfer_endpoint "$PAYEE_PROXY_TRANSFER_ENDPOINT"

# Give the ml-api-adapter endpoint cache time to drop the previous wallet2 endpoint.
sleep 2

http_post_json "$OUTBOUND_BASE/lookup" "{
  \"destination\": \"${WALLET2_CONNECTOR_ID}\",
  \"type\": \"${WALLET2_PARTY_ID_TYPE_VALUE}\",
  \"id\": \"${WALLET2_PARTY_ID_VALUE}\"
}" "$WALLET1_CONNECTOR_ID"
require_2xx "Outbound lookup"
lookup_response="$HTTP_BODY"

quote_request="$(
  LOOKUP_RESPONSE="$lookup_response" \
  WALLET1_CONNECTOR_ID="$WALLET1_CONNECTOR_ID" \
  WALLET1_PARTY_ID_TYPE_VALUE="$WALLET1_PARTY_ID_TYPE_VALUE" \
  WALLET1_PARTY_ID_VALUE="$WALLET1_PARTY_ID_VALUE" \
  WALLET1_CURRENCY_VALUE="$WALLET1_CURRENCY_VALUE" \
  node <<'NODE'
const lookup = JSON.parse(process.env.LOOKUP_RESPONSE)
const payee = lookup.payee?.partyIdInfo
if (!payee) {
  throw new Error('lookup response did not include payee.partyIdInfo')
}
const request = {
  scenario: 'TRANSFER',
  subScenario: process.env.QUOTE_SUB_SCENARIO?.trim() || 'PERSON_TO_PERSON',
  amountType: 'SEND',
  amount: { amount: '10', currency: process.env.WALLET1_CURRENCY_VALUE },
  payer: {
    partyIdType: process.env.WALLET1_PARTY_ID_TYPE_VALUE,
    partyIdentifier: process.env.WALLET1_PARTY_ID_VALUE,
    fspId: process.env.WALLET1_CONNECTOR_ID
  },
  payee
}
process.stdout.write(JSON.stringify(request))
NODE
)"

http_post_json "$OUTBOUND_BASE/quote" "$quote_request" "$WALLET1_CONNECTOR_ID"
require_2xx "Outbound quote"
quote_response="$HTTP_BODY"

transfer_request="$(
  QUOTE_RESPONSE="$quote_response" \
  WALLET2_CONNECTOR_ID="$WALLET2_CONNECTOR_ID" \
  REPRO_TRANSFER_EXPIRY_SECONDS="$REPRO_TRANSFER_EXPIRY_SECONDS" \
  node <<'NODE'
const quote = JSON.parse(process.env.QUOTE_RESPONSE)
const expirySeconds = Number.parseInt(process.env.REPRO_TRANSFER_EXPIRY_SECONDS, 10)
const expiration = new Date(Date.now() + expirySeconds * 1000).toISOString()
const request = {
  quoteId: quote.quoteId,
  payeeFsp: process.env.WALLET2_CONNECTOR_ID,
  transferAmount: quote.transferAmount,
  ilpPacket: quote.ilpPacket,
  condition: quote.condition,
  expiration
}
process.stdout.write(JSON.stringify(request))
NODE
)"

TRANSFER_ID="$(
  TRANSFER_REQUEST="$transfer_request" node <<'NODE'
const request = JSON.parse(process.env.TRANSFER_REQUEST)
process.stdout.write(request.quoteId)
NODE
)"

echo "Running delayed notification repro"
echo "transferId=$TRANSFER_ID"
echo "wallet2 transfer endpoint=$PAYEE_PROXY_TRANSFER_ENDPOINT"
echo "payee delay=${REPRO_PAYEE_DELAY_MS}ms, transfer expiry=${REPRO_TRANSFER_EXPIRY_SECONDS}s"

http_post_json "$OUTBOUND_BASE/transfer" "$transfer_request" "$WALLET1_CONNECTOR_ID"
transfer_status="$HTTP_STATUS"
transfer_response="$HTTP_BODY"

sleep "$REPRO_POST_TRANSFER_WAIT_SECONDS"

echo
echo "Transfer HTTP status: $transfer_status"
echo "$transfer_response" | node -e "
  const fs = require('node:fs')
  const body = fs.readFileSync(0, 'utf8')
  try {
    console.log(JSON.stringify(JSON.parse(body), null, 2))
  } catch {
    console.log(body)
  }
"

echo
echo "Kafka notification group lag:"
"$KAFKA_HOME/bin/kafka-consumer-groups.sh" \
  --bootstrap-server 127.0.0.1:9092 \
  --describe \
  --group ml-group-notification-event || true

echo
echo "Evidence log lines:"
for log_file in \
  "$LOG_DIR/central-ledger-handlers.log" \
  "$LOG_DIR/ml-api-adapter-handler.log" \
  "$LOG_DIR/payee-delay-proxy.log" \
  "$LOG_DIR/wallet2-connector.log" \
  "$LOG_DIR/wallet1-connector.log"; do
  [ -f "$log_file" ] || continue
  echo "== $log_file =="
  rg -n "$TRANSFER_ID|Transfer expired|non-RESERVED|reservedAbortedTransfer|timeout-received" "$log_file" | tail -80 || true
done

if [[ "$transfer_status" =~ ^2 ]]; then
  transfer_state="$(
    TRANSFER_RESPONSE="$transfer_response" node <<'NODE' || true
const response = JSON.parse(process.env.TRANSFER_RESPONSE)
process.stdout.write(response.response?.transferState || response.transferState || '')
NODE
  )"
  if [ "$transfer_state" = "COMMITTED" ]; then
    echo "Repro did not trigger: transfer committed successfully." >&2
    exit 1
  fi
fi

if ! rg -q "$TRANSFER_ID.*non-RESERVED|non-RESERVED.*$TRANSFER_ID" "$LOG_DIR/central-ledger-handlers.log" 2>/dev/null; then
  echo "Repro ran, but central-ledger-handlers.log does not yet show non-RESERVED for $TRANSFER_ID." >&2
  echo "Increase REPRO_PAYEE_DELAY_MS or REPRO_POST_TRANSFER_WAIT_SECONDS and retry." >&2
  exit 1
fi

echo
echo "Repro confirmed: late payee fulfil hit non-RESERVED transfer state."
