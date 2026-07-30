#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

WALLET1_ENV_FILE="$CONF_DIR/wallet1.env"
WALLET2_ENV_FILE="$CONF_DIR/wallet2.env"

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
WALLET1_CC_PORT="$WALLET_CC_PORT"
WALLET1_PARTY_ID_TYPE_VALUE="$PARTY_ID_TYPE"
WALLET1_PARTY_ID_VALUE="$PARTY_ID"
WALLET1_CURRENCY_VALUE="$CURRENCY"
WALLET1_SUB_SCENARIO_VALUE="${TRANSFER_SUB_SCENARIO:-SUBSCENARIO}"

set -a
source "$WALLET2_ENV_FILE"
set +a
WALLET2_CONNECTOR_ID="$CONNECTOR_ID"
WALLET2_PARTY_ID_TYPE_VALUE="$PARTY_ID_TYPE"
WALLET2_PARTY_ID_VALUE="$PARTY_ID"

"$LOCAL_HOME/scripts/start-wallet-stack.sh"
WALLET_STACK=core "$LOCAL_HOME/scripts/onboard-wallet1.sh"
WALLET_STACK=core "$LOCAL_HOME/scripts/onboard-wallet2.sh"

CC_BASE="http://127.0.0.1:${WALLET1_CC_PORT}"
TRANSFER_ID="$(node -e "console.log(require('node:crypto').randomUUID())")"
HOME_TRANSACTION_ID="$(node -e "console.log(require('node:crypto').randomUUID())")"

request_json() {
  local method="$1"
  local path="$2"
  local body="$3"
  curl -fsS \
    -X "$method" \
    -H 'Content-Type: application/json' \
    "$CC_BASE$path" \
    --data-raw "$body"
}

send_money_response="$(
  request_json POST "/sendmoney" "{
    \"homeTransactionId\": \"${HOME_TRANSACTION_ID}\",
    \"from\": {
      \"idType\": \"${WALLET1_PARTY_ID_TYPE_VALUE}\",
      \"idValue\": \"${WALLET1_PARTY_ID_VALUE}\",
      \"fspId\": \"${WALLET1_CONNECTOR_ID}\"
    },
    \"to\": {
      \"idType\": \"${WALLET2_PARTY_ID_TYPE_VALUE}\",
      \"idValue\": \"${WALLET2_PARTY_ID_VALUE}\",
      \"fspId\": \"${WALLET2_CONNECTOR_ID}\"
    },
    \"amountType\": \"SEND\",
    \"currency\": \"${WALLET1_CURRENCY_VALUE}\",
    \"amount\": \"10\",
    \"transactionType\": \"TRANSFER\",
    \"subScenario\": \"${WALLET1_SUB_SCENARIO_VALUE}\",
    \"note\": \"wallet1-wallet2-local\"
  }"
)"

TRANSFER_ID="$(echo "$send_money_response" | node -e "const response = JSON.parse(require('fs').readFileSync(0, 'utf8')); process.stdout.write(response.transferId);")"

accept_party_response="$(
  request_json PUT "/sendmoney/${TRANSFER_ID}" '{
    "acceptParty": true,
    "amount": 10
  }'
)"

accept_quote_response="$(
  request_json PUT "/sendmoney/${TRANSFER_ID}" '{
    "acceptQuote": true
  }'
)"

final_transfer_response=''
for _ in $(seq 1 60); do
  final_transfer_response="$(curl -fsS "$CC_BASE/transfers/${TRANSFER_ID}")"
  current_state="$(echo "$final_transfer_response" | node -e "const response = JSON.parse(require('fs').readFileSync(0, 'utf8')); process.stdout.write(String(response.currentState ?? ''));")"
  if [ "$current_state" = "COMPLETED" ] || [ "$current_state" = "succeeded" ]; then
    break
  fi
  sleep 1
done

node -e "
  const sendMoney = JSON.parse(process.argv[1]);
  const acceptParty = JSON.parse(process.argv[2]);
  const acceptQuote = JSON.parse(process.argv[3]);
  const transfer = JSON.parse(process.argv[4]);
  if (!['COMPLETED', 'succeeded'].includes(transfer.currentState)) {
    console.error(JSON.stringify({ sendMoney, acceptParty, acceptQuote, transfer }, null, 2));
    process.exit(1);
  }
  console.log(JSON.stringify({ sendMoney, acceptParty, acceptQuote, transfer }, null, 2));
" "$send_money_response" "$accept_party_response" "$accept_quote_response" "$final_transfer_response"
