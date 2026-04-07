#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

WALLET1_ENV_FILE="$CONF_DIR/wallet1-mtpa.env"
WALLET2_ENV_FILE="$CONF_DIR/wallet2-mtpa.env"

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
WALLET2_PARTY_ID_TYPE_VALUE="$WALLET2_PARTY_ID_TYPE"
WALLET2_PARTY_ID_VALUE="$WALLET2_PARTY_ID"

AUTH_HEADER='Bearer a.b.c'
OUTBOUND_BASE="http://127.0.0.1:${WALLET1_OUTBOUND_PORT}"

post_json() {
  local path="$1"
  local body="$2"
  curl -fsS \
    -H 'Content-Type: application/json' \
    -H "fspiop-source: ${WALLET1_CONNECTOR_ID}" \
    -H "authorization: ${AUTH_HEADER}" \
    "$OUTBOUND_BASE$path" \
    --data-raw "$body"
}

lookup_response="$(
  post_json "/lookup" "{
    \"destination\": \"${WALLET2_CONNECTOR_ID}\",
    \"type\": \"${WALLET2_PARTY_ID_TYPE_VALUE}\",
    \"id\": \"${WALLET2_PARTY_ID_VALUE}\"
  }"
)"

quote_request="$(
  echo "$lookup_response" | node -e "
    const lookup = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const payee = lookup.payee?.partyIdInfo;
    if (!payee) process.exit(1);
    const payer = {
      partyIdType: '$WALLET1_PARTY_ID_TYPE_VALUE',
      partyIdentifier: '$WALLET1_PARTY_ID_VALUE',
      fspId: '$WALLET1_CONNECTOR_ID'
    };
    const request = {
      scenario: 'TRANSFER',
      subScenario: process.env.QUOTE_SUB_SCENARIO?.trim() || undefined,
      amountType: 'SEND',
      amount: { amount: '10', currency: '$WALLET1_CURRENCY_VALUE' },
      payer,
      payee
    };
    process.stdout.write(JSON.stringify(request));
  "
)"

quote_response="$(post_json "/quote" "$quote_request")"

transfer_request="$(
  echo "$quote_response" | node -e "
    const quote = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    process.stdout.write(JSON.stringify({
      quoteId: quote.quoteId,
      payeeFsp: '$WALLET2_CONNECTOR_ID',
      transferAmount: quote.transferAmount,
      ilpPacket: quote.ilpPacket,
      condition: quote.condition,
      expiration: quote.expiration
    }));
  "
)"

transfer_response="$(post_json "/transfer" "$transfer_request")"

node -e "
  const lookup = JSON.parse(process.argv[1]);
  const quote = JSON.parse(process.argv[2]);
  const transfer = JSON.parse(process.argv[3]);
  const transferState = transfer.response?.transferState ?? transfer.transferState;
  if (transferState !== 'COMMITTED') {
    console.error(JSON.stringify({ lookup, quote, transfer }, null, 2));
    process.exit(1);
  }
  console.log(JSON.stringify({ lookup, quote, transfer }, null, 2));
" "$lookup_response" "$quote_response" "$transfer_response"
