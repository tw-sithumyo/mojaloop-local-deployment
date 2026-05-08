#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

MYSQL_DATA_DIR="$DATA_DIR/mysql"
MYSQL_SOCKET="$RUN_DIR/mysql.sock"

mkdir -p "$MYSQL_DATA_DIR"

if [ ! -d "$MYSQL_DATA_DIR/mysql" ]; then
  "$RUNTIME_ROOT/usr/bin/mariadb-install-db" \
    --basedir="$RUNTIME_ROOT/usr" \
    --datadir="$MYSQL_DATA_DIR" \
    --auth-root-authentication-method=normal \
    --skip-test-db \
    --user="$(id -un)"
fi

cat > "$CONF_DIR/my.cnf" <<EOF
[mysqld]
basedir=$RUNTIME_ROOT/usr
datadir=$MYSQL_DATA_DIR
socket=$MYSQL_SOCKET
port=3306
bind-address=127.0.0.1
pid-file=$RUN_DIR/mysqld.pid
log-error=$LOG_DIR/mariadb.err
skip-networking=0
max_connections=500
EOF
