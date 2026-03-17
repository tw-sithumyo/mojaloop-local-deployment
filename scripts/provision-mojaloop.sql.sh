#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

cat > "$CONF_DIR/bootstrap.sql" <<'EOF'
CREATE DATABASE IF NOT EXISTS central_ledger;
CREATE DATABASE IF NOT EXISTS account_lookup;
CREATE USER IF NOT EXISTS 'central_ledger'@'127.0.0.1' IDENTIFIED BY 'password';
CREATE USER IF NOT EXISTS 'central_ledger'@'localhost' IDENTIFIED BY 'password';
CREATE USER IF NOT EXISTS 'account_lookup'@'127.0.0.1' IDENTIFIED BY 'password';
CREATE USER IF NOT EXISTS 'account_lookup'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON central_ledger.* TO 'central_ledger'@'127.0.0.1';
GRANT ALL PRIVILEGES ON central_ledger.* TO 'central_ledger'@'localhost';
GRANT ALL PRIVILEGES ON account_lookup.* TO 'account_lookup'@'127.0.0.1';
GRANT ALL PRIVILEGES ON account_lookup.* TO 'account_lookup'@'localhost';
FLUSH PRIVILEGES;
EOF

"$RUNTIME_ROOT/usr/bin/mariadb" -h 127.0.0.1 -P 3306 -u root < "$CONF_DIR/bootstrap.sql"
