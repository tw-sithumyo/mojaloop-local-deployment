#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

ENV_FILE="$CONF_DIR/wallet1-pivotal.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing wallet1 env file: $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

AUTH_HEADER='Bearer a.b.c'
OUTBOUND_BASE="http://127.0.0.1:${WEB_OUTBOUND_PORT}"

post_json() {
  local path="$1"
  local body="$2"
  curl -fsS \
    -H 'Content-Type: application/json' \
    -H "fspiop-source: ${CONNECTOR_ID}" \
    -H "authorization: ${AUTH_HEADER}" \
    "$OUTBOUND_BASE$path" \
    --data-raw "$body"
}

put_json() {
  local path="$1"
  local body="$2"
  curl -fsS \
    -X PUT \
    -H 'Content-Type: application/json' \
    -H "fspiop-source: ${CONNECTOR_ID}" \
    -H "authorization: ${AUTH_HEADER}" \
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
        idType: '$WALLET1_PARTY_ID_TYPE',
        idValue: '$WALLET1_PARTY_ID',
        idSubValue: '',
        displayName: 'Wallet1 User',
        fspId: '$CONNECTOR_ID'
      },
      to: {
        type: 'CONSUMER',
        idType: '$WALLET1_PARTY_ID_TYPE',
        idValue: '$WALLET1_PARTY_ID',
        idSubValue: '',
        fspId: '$CONNECTOR_ID'
      },
      amountType: 'SEND',
      amount: '10',
      currency: '$WALLET1_CURRENCY',
      transactionType: 'TRANSFER',
      subScenario: process.env.QUOTE_SUB_SCENARIO?.trim() || 'PERSON_TO_PERSON',
      note: 'wallet1 local self-flow'
    };
    process.stdout.write(JSON.stringify(request));
  "
)"

party_response="$(post_json "/secured/sendmoney" "$sendmoney_request")"
transfer_id="$(echo "$party_response" | "$NODE_HOME/bin/node" -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf8')); process.stdout.write(data.transferId);")"
quote_response="$(put_json "/secured/sendmoney/$transfer_id" '{"acceptParty":true}')"
transfer_response="$(put_json "/secured/sendmoney/$transfer_id" '{"acceptQuote":true}')"

node -e "
  const party = JSON.parse(process.argv[1]);
  const quote = JSON.parse(process.argv[2]);
  const transfer = JSON.parse(process.argv[3]);
  console.log(JSON.stringify({ party, quote, transfer }, null, 2));
" "$party_response" "$quote_response" "$transfer_response"
