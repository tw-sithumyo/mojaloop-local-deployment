#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

TRANSFER_COUNT="${DASHBOARD_TRANSFER_COUNT:-20}"
MIN_AMOUNT="${DASHBOARD_TRANSFER_MIN_AMOUNT:-5}"
MAX_AMOUNT="${DASHBOARD_TRANSFER_MAX_AMOUNT:-75}"
SUB_SCENARIOS="${DASHBOARD_TRANSFER_SUB_SCENARIOS:-PERSON_TO_PERSON,PERSON_TO_BUSINESS,BUSINESS_TO_PERSON,BUSINESS_TO_BUSINESS,GOVERNMENT_TO_PERSON,PERSON_TO_GOVERNMENT,TRANSFER_TO_SELF}"
REFRESH_ROLLUP="${DASHBOARD_REFRESH_ROLLUP:-1}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RESULT_LOG="$LOG_DIR/dashboard-random-transfers-$RUN_ID.tsv"

require_positive_integer() {
  local name="$1"
  local value="$2"

  if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ]; then
    echo "$name must be a positive integer; received '$value'." >&2
    exit 1
  fi
}

require_positive_integer DASHBOARD_TRANSFER_COUNT "$TRANSFER_COUNT"
require_positive_integer DASHBOARD_TRANSFER_MIN_AMOUNT "$MIN_AMOUNT"
require_positive_integer DASHBOARD_TRANSFER_MAX_AMOUNT "$MAX_AMOUNT"

if [ "$MIN_AMOUNT" -gt "$MAX_AMOUNT" ]; then
  echo "DASHBOARD_TRANSFER_MIN_AMOUNT must not exceed DASHBOARD_TRANSFER_MAX_AMOUNT." >&2
  exit 1
fi

if [ "$REFRESH_ROLLUP" != "0" ] && [ "$REFRESH_ROLLUP" != "1" ]; then
  echo "DASHBOARD_REFRESH_ROLLUP must be 0 or 1." >&2
  exit 1
fi

IFS=',' read -r -a raw_scenarios <<< "$SUB_SCENARIOS"
scenarios=()

for raw_scenario in "${raw_scenarios[@]}"; do
  scenario="${raw_scenario//[[:space:]]/}"
  if ! [[ "$scenario" =~ ^[A-Z][A-Z0-9_]{0,31}$ ]]; then
    echo "Invalid sub-scenario '$raw_scenario'; use 1-32 uppercase letters, numbers, or underscores." >&2
    exit 1
  fi
  scenarios+=("$scenario")
done

if [ "${#scenarios[@]}" -eq 0 ]; then
  echo "DASHBOARD_TRANSFER_SUB_SCENARIOS must contain at least one value." >&2
  exit 1
fi

db=(
  "$RUNTIME_ROOT/usr/bin/mariadb"
  --host=127.0.0.1
  --port=3306
  --user=central_ledger
  --password=password
  central_ledger
)

for scenario in "${scenarios[@]}"; do
  "${db[@]}" -e "
    INSERT INTO transactionSubScenario (name, description)
    SELECT '$scenario', 'Local dashboard transfer generator'
    WHERE NOT EXISTS (
      SELECT 1 FROM transactionSubScenario WHERE name = '$scenario'
    );
  " >/dev/null
done

random_between() {
  local minimum="$1"
  local maximum="$2"
  local span=$((maximum - minimum + 1))
  local random_value=$((RANDOM * 32768 + RANDOM))

  echo $((minimum + random_value % span))
}

printf 'sequence\ttransfer_id\tsub_scenario\tamount\tstate\n' > "$RESULT_LOG"
successes=0
failures=0

echo "Generating $TRANSFER_COUNT wallet1 -> wallet2 transfers..."

for sequence in $(seq 1 "$TRANSFER_COUNT"); do
  scenario="${scenarios[$((RANDOM % ${#scenarios[@]}))]}"
  amount="$(random_between "$MIN_AMOUNT" "$MAX_AMOUNT")"
  output_file="$(mktemp "$RUN_DIR/dashboard-transfer.XXXXXX.json")"

  if QUOTE_SUB_SCENARIO="$scenario" TRANSFER_AMOUNT="$amount" \
      "$LOCAL_HOME/scripts/test-wallet1-wallet2-flow.sh" > "$output_file" 2>&1; then
    parsed="$($NODE_HOME/bin/node - "$output_file" <<'NODE'
const fs = require('node:fs');
const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
process.stdout.write(`${data.party.transferId}\t${data.transfer.currentState}\t${data.party.subScenario ?? ''}`);
NODE
    )"
    transfer_id="${parsed%%$'\t'*}"
    parsed="${parsed#*$'\t'}"
    state="${parsed%%$'\t'*}"
    actual_scenario="${parsed#*$'\t'}"
    if [ "$actual_scenario" != "$scenario" ]; then
      echo "[$sequence/$TRANSFER_COUNT] requested $scenario but Pivotal returned ${actual_scenario:-<empty>}." >&2
      failures=$((failures + 1))
      printf '%s\t%s\t%s\t%s\tSCENARIO_MISMATCH\n' "$sequence" "$transfer_id" "$scenario" "$amount" >> "$RESULT_LOG"
      rm -f "$output_file"
      continue
    fi
    successes=$((successes + 1))
    printf '%s\t%s\t%s\t%s\t%s\n' "$sequence" "$transfer_id" "$scenario" "$amount" "$state" >> "$RESULT_LOG"
    printf '[%02d/%02d] %-24s amount=%-3s %s\n' "$sequence" "$TRANSFER_COUNT" "$scenario" "$amount" "$state"
  else
    failures=$((failures + 1))
    printf '%s\t-\t%s\t%s\tFAILED\n' "$sequence" "$scenario" "$amount" >> "$RESULT_LOG"
    echo "[$sequence/$TRANSFER_COUNT] $scenario amount=$amount FAILED; response follows:" >&2
    sed -n '1,80p' "$output_file" >&2
  fi

  rm -f "$output_file"
done

if [ "$REFRESH_ROLLUP" = "1" ]; then
  echo "Refreshing dashboard rollup by restarting the local app-auditor..."
  "$LOCAL_HOME/scripts/stop-pivotal-auditor.sh"
  "$LOCAL_HOME/scripts/start-pivotal-auditor.sh"
fi

echo "Generated transfers: successful=$successes failed=$failures"
echo "Results: $RESULT_LOG"

if [ "$failures" -gt 0 ]; then
  exit 1
fi
