#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

INIT_SQL="$DEMOWALLET_HOME/init-multi.sql"

if [ ! -f "$INIT_SQL" ]; then
  echo "Missing DemoWallet init SQL: $INIT_SQL" >&2
  exit 1
fi

if ! "$RUNTIME_ROOT/usr/bin/mariadb-admin" --protocol=tcp -h 127.0.0.1 -P 3306 -u root ping >/dev/null 2>&1; then
  echo "MariaDB is not running on 127.0.0.1:3306. Run local/scripts/start-infra.sh first." >&2
  exit 1
fi

"$RUNTIME_ROOT/usr/bin/mariadb" -h 127.0.0.1 -P 3306 -u root < "$INIT_SQL"

"$RUNTIME_ROOT/usr/bin/mariadb" -h 127.0.0.1 -P 3306 -u root <<'SQL'
CREATE USER IF NOT EXISTS 'central_ledger'@'127.0.0.1' IDENTIFIED BY 'password';
CREATE USER IF NOT EXISTS 'central_ledger'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON wallet1.* TO 'central_ledger'@'127.0.0.1';
GRANT ALL PRIVILEGES ON wallet1.* TO 'central_ledger'@'localhost';
GRANT ALL PRIVILEGES ON wallet2.* TO 'central_ledger'@'127.0.0.1';
GRANT ALL PRIVILEGES ON wallet2.* TO 'central_ledger'@'localhost';
FLUSH PRIVILEGES;
SQL
