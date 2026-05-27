#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

"$LOCAL_HOME/scripts/init-mariadb.sh"
mkdir -p "$DATA_DIR/kafka-logs" "$DATA_DIR/valkey"

if ! [ -f "$RUN_DIR/valkey.pid" ] || ! kill -0 "$(cat "$RUN_DIR/valkey.pid")" 2>/dev/null; then
  "$RUNTIME_ROOT/usr/bin/valkey-server" \
    --bind 127.0.0.1 \
    --port 6379 \
    --daemonize yes \
    --dir "$DATA_DIR/valkey" \
    --pidfile "$RUN_DIR/valkey.pid" \
    --logfile "$LOG_DIR/valkey.log"
fi

if ! [ -f "$RUN_DIR/mysqld.pid" ] || ! kill -0 "$(cat "$RUN_DIR/mysqld.pid")" 2>/dev/null; then
  setsid -f "$RUNTIME_ROOT/usr/bin/mariadbd" \
    --defaults-file="$CONF_DIR/my.cnf" \
    --user="$(id -un)" \
    >"$LOG_DIR/mariadb.stdout" 2>&1 < /dev/null
  for _ in $(seq 1 60); do
    if "$RUNTIME_ROOT/usr/bin/mariadb-admin" --protocol=tcp -h 127.0.0.1 -P 3306 -u root ping >/dev/null 2>&1; then
      pgrep -af 'mariadbd .*local/config/my.cnf' | awk 'NR==1 {print $1}' > "$RUN_DIR/mysqld.pid"
      break
    fi
    sleep 1
  done
fi

"$RUNTIME_ROOT/usr/bin/mariadb" -h 127.0.0.1 -P 3306 -u root \
  -e "SET GLOBAL max_connections=500;" >/dev/null

cat > "$CONF_DIR/kafka.properties" <<EOF
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@127.0.0.1:9093
listeners=PLAINTEXT://127.0.0.1:9092,CONTROLLER://127.0.0.1:9093
advertised.listeners=PLAINTEXT://127.0.0.1:9092
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=$DATA_DIR/kafka-logs
num.partitions=3
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
group.initial.rebalance.delay.ms=0
EOF

if [ ! -f "$DATA_DIR/kafka-logs/meta.properties" ]; then
  KAFKA_CLUSTER_ID="$("$KAFKA_HOME/bin/kafka-storage.sh" random-uuid)"
  "$KAFKA_HOME/bin/kafka-storage.sh" format -t "$KAFKA_CLUSTER_ID" -c "$CONF_DIR/kafka.properties"
fi

if ! [ -f "$RUN_DIR/kafka.pid" ] || ! kill -0 "$(cat "$RUN_DIR/kafka.pid")" 2>/dev/null; then
  export KAFKA_HEAP_OPTS="${KAFKA_HEAP_OPTS:--Xms256M -Xmx512M}"
  setsid -f "$KAFKA_HOME/bin/kafka-server-start.sh" "$CONF_DIR/kafka.properties" >"$LOG_DIR/kafka.log" 2>&1 < /dev/null
  for _ in $(seq 1 60); do
    if "$KAFKA_HOME/bin/kafka-topics.sh" --bootstrap-server 127.0.0.1:9092 --list >/dev/null 2>&1; then
      pgrep -af 'kafka\.Kafka' | awk 'NR==1 {print $1}' > "$RUN_DIR/kafka.pid"
      break
    fi
    sleep 1
  done
fi

"$LOCAL_HOME/scripts/provision-mojaloop.sql.sh"
"$LOCAL_HOME/scripts/provision-kafka-topics.sh"
