#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

MYSQL="$RUNTIME_ROOT/usr/bin/mariadb"

if ! "$RUNTIME_ROOT/usr/bin/mariadb-admin" --protocol=tcp -h 127.0.0.1 -P 3306 -u root ping >/dev/null 2>&1; then
  echo "MariaDB is not running on 127.0.0.1:3306. Run local/scripts/start-infra.sh first." >&2
  exit 1
fi

"$MYSQL" -h 127.0.0.1 -P 3306 -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS pivotal;
CREATE USER IF NOT EXISTS 'pivotal'@'127.0.0.1' IDENTIFIED BY 'password';
CREATE USER IF NOT EXISTS 'pivotal'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON pivotal.* TO 'pivotal'@'127.0.0.1';
GRANT ALL PRIVILEGES ON pivotal.* TO 'pivotal'@'localhost';
FLUSH PRIVILEGES;
SQL
