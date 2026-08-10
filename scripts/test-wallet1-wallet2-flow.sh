#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

# Preserve per-run overrides before wallet defaults are loaded.
REQUEST_SUB_SCENARIO="${QUOTE_SUB_SCENARIO:-}"

WALLET_STACK="${WALLET_STACK:-pivotal}"
case "$WALLET_STACK" in
  pivotal)
    ;;
  core|core-connector)
    exec env WALLET_STACK=core "$LOCAL_HOME/scripts/test-core-connector-flow.sh"
    ;;
  *)
    echo "Unsupported WALLET_STACK: $WALLET_STACK (expected pivotal or core)" >&2
    exit 1
    ;;
esac

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

QUOTE_SUB_SCENARIO="${REQUEST_SUB_SCENARIO:-${QUOTE_SUB_SCENARIO:-PERSON_TO_PERSON}}"
export QUOTE_SUB_SCENARIO

WALLET2_CONNECTOR_ID="$CONNECTOR_ID"
WALLET2_PARTY_ID_TYPE_VALUE="$WALLET2_PARTY_ID_TYPE"
WALLET2_PARTY_ID_VALUE="$WALLET2_PARTY_ID"

OUTBOUND_BASE="http://127.0.0.1:${WALLET1_OUTBOUND_PORT}"
TRANSFER_AMOUNT="${TRANSFER_AMOUNT:-10}"
ACCESS_PRIVATE_KEY="${ACCESS_PRIVATE_KEY:-$CONF_DIR/access-keys/wallet1-access-private-key.pem}"

if [ ! -f "$ACCESS_PRIVATE_KEY" ]; then
  echo "Missing wallet1 access private key: $ACCESS_PRIVATE_KEY" >&2
  exit 1
fi

sign_body() {
  local body="$1"
  printf '%s' "$body" | "$LOCAL_HOME/scripts/sign-pivotal-access-jwt.sh" "$ACCESS_PRIVATE_KEY" -
}

post_json() {
  local path="$1"
  local body="$2"
  local authorization
  authorization="$(sign_body "$body")"
  curl -fsS \
    -H 'Content-Type: application/json' \
    -H "fspiop-source: ${WALLET1_CONNECTOR_ID}" \
    -H "authorization: ${authorization}" \
    "$OUTBOUND_BASE$path" \
    --data-raw "$body"
}

put_json() {
  local path="$1"
  local body="$2"
  local authorization
  authorization="$(sign_body "$body")"
  curl -fsS \
    -X PUT \
    -H 'Content-Type: application/json' \
    -H "fspiop-source: ${WALLET1_CONNECTOR_ID}" \
    -H "authorization: ${authorization}" \
    "$OUTBOUND_BASE$path" \
    --data-raw "$body"
}

sendmoney_request="$(
  "$NODE_HOME/bin/node" -e "
    const crypto = require('node:crypto');
    const request = {
      homeTransactionId: crypto.randomUUID(),
      from: {
        type: 'CONSUMER',
        idType: '$WALLET1_PARTY_ID_TYPE_VALUE',
        idValue: '$WALLET1_PARTY_ID_VALUE',
        idSubValue: '',
        displayName: 'Wallet1 User',
        fspId: '$WALLET1_CONNECTOR_ID'
      },
      to: {
        type: 'CONSUMER',
        idType: '$WALLET2_PARTY_ID_TYPE_VALUE',
        idValue: '$WALLET2_PARTY_ID_VALUE',
        idSubValue: '',
        fspId: '$WALLET2_CONNECTOR_ID'
      },
      amountType: 'SEND',
      amount: '$TRANSFER_AMOUNT',
      currency: '$WALLET1_CURRENCY_VALUE',
      transactionType: 'TRANSFER',
      subScenario: process.env.QUOTE_SUB_SCENARIO?.trim() || 'PERSON_TO_PERSON',
      note: 'wallet1 to wallet2 local flow'
    };
    process.stdout.write(JSON.stringify(request));
  "
)"

party_response="$(post_json "/secured/sendmoney" "$sendmoney_request")"
transfer_id="$(echo "$party_response" | "$NODE_HOME/bin/node" -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf8')); process.stdout.write(data.transferId);")"
quote_response="$(put_json "/secured/sendmoney/$transfer_id" "{\"acceptParty\":true,\"amount\":\"$TRANSFER_AMOUNT\"}")"
transfer_response="$(put_json "/secured/sendmoney/$transfer_id" '{"acceptQuote":true}')"

node -e "
  const party = JSON.parse(process.argv[1]);
  const quote = JSON.parse(process.argv[2]);
  const transfer = JSON.parse(process.argv[3]);
  const currentState = transfer.currentState;
  if (currentState !== 'COMPLETED') {
    console.error(JSON.stringify({ party, quote, transfer }, null, 2));
    process.exit(1);
  }
  console.log(JSON.stringify({ party, quote, transfer }, null, 2));
" "$party_response" "$quote_response" "$transfer_response"
