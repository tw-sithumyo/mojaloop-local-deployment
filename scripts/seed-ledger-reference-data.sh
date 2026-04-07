#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

DB_CLIENT="$RUNTIME_ROOT/usr/bin/mariadb"
DB_OPTS=(
  --host=127.0.0.1
  --port=3306
  --user=central_ledger
  --password=password
  central_ledger
)

table_exists="$("$DB_CLIENT" "${DB_OPTS[@]}" -Nse \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'central_ledger' AND table_name = 'transactionSubScenario';")"

if [ "${table_exists:-0}" != "1" ]; then
  exit 0
fi

"$DB_CLIENT" "${DB_OPTS[@]}" <<'SQL'
INSERT INTO transactionSubScenario (name, description)
SELECT src.name, src.description
FROM (
  SELECT 'PERSON_TO_PERSON' AS name, 'Local P2P wallet transfer' AS description
  UNION ALL
  SELECT 'TRANSFER_TO_SELF', 'Local wallet self-transfer test'
  UNION ALL
  SELECT 'GOVERNMENT_TO_PERSON', 'Local G2P transfer test'
) AS src
LEFT JOIN transactionSubScenario AS tss
  ON tss.name = src.name
WHERE tss.transactionSubScenarioId IS NULL;
SQL
