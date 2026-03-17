#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

TOPICS=(
  topic-transfer-prepare
  topic-transfer-position
  topic-transfer-position-batch
  topic-transfer-fulfil
  topic-notification-event
  topic-transfer-get
  topic-admin-transfer
  topic-bulk-prepare
  topic-bulk-fulfil
  topic-bulk-processing
  topic-bulk-get
  topic-quotes-post
  topic-quotes-put
  topic-quotes-get
  topic-bulkquotes-post
  topic-bulkquotes-put
  topic-bulkquotes-get
  topic-fx-quotes-post
  topic-fx-quotes-put
  topic-fx-quotes-get
  topic-deferredsettlement-close
)

for topic in "${TOPICS[@]}"; do
  "$KAFKA_HOME/bin/kafka-topics.sh" \
    --bootstrap-server 127.0.0.1:9092 \
    --create \
    --if-not-exists \
    --topic "$topic" \
    --replication-factor 1 \
    --partitions 3 >/dev/null
done
