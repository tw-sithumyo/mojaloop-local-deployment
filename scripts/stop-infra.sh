#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

stop_named_process kafka "$RUN_DIR/kafka.pid" 9092 'kafka\.Kafka'
stop_named_process nats "$RUN_DIR/nats.pid" 4222 'nats-server'
stop_named_process valkey "$RUN_DIR/valkey.pid" 6379 'valkey-server'
stop_named_process mariadb "$RUN_DIR/mysqld.pid" 3306 'mariadbd .*local/config/my\.cnf'
