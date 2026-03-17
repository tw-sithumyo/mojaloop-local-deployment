#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

ENV_FILE="$CONF_DIR/wallet1-mtpa.env"

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

lookup_response="$(
  post_json "/lookup" "{
    \"destination\": \"${CONNECTOR_ID}\",
    \"type\": \"${WALLET1_PARTY_ID_TYPE}\",
    \"id\": \"${WALLET1_PARTY_ID}\"
  }"
)"

quote_request="$(
  echo "$lookup_response" | node -e "
    const lookup = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const payee = lookup.payee?.partyIdInfo;
    if (!payee) process.exit(1);
    const payer = {
      partyIdType: '$WALLET1_PARTY_ID_TYPE',
      partyIdentifier: '$WALLET1_PARTY_ID',
      fspId: '$CONNECTOR_ID'
    };
    process.stdout.write(JSON.stringify({
      scenario: 'TRANSFER',
      amountType: 'SEND',
      amount: { amount: '10', currency: '$WALLET1_CURRENCY' },
      payer,
      payee
    }));
  "
)"

quote_response="$(post_json "/quote" "$quote_request")"

transfer_request="$(
  echo "$quote_response" | node -e "
    const quote = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    process.stdout.write(JSON.stringify({
      quoteId: quote.quoteId,
      payeeFsp: '$CONNECTOR_ID',
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
  console.log(JSON.stringify({ lookup, quote, transfer }, null, 2));
" "$lookup_response" "$quote_response" "$transfer_response"
