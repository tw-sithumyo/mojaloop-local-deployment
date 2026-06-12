#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/env.sh"

WALLET="wallet2"
ENV_FILE="$CONF_DIR/${WALLET}-pivotal.env"
BIGBANK_CONNECTOR_HOME="${BIGBANK_CONNECTOR_HOME:-$ROOT_DIR/pivotal-gin-big-bank-java-connector}"
BIGBANK_MOCK_PORT="${BIGBANK_MOCK_PORT:-9082}"
BIGBANK_MOCK_URL="http://127.0.0.1:${BIGBANK_MOCK_PORT}/"
BIGBANK_MOCK_PID_FILE="$RUN_DIR/pivotal-bigbank-mock.pid"
BIGBANK_MOCK_LOG_FILE="$LOG_DIR/pivotal-bigbank-mock.log"
CONNECTOR_NAME="${WALLET}-pivotal-connector"
CONNECTOR_PID_FILE="$RUN_DIR/${CONNECTOR_NAME}.pid"
CONNECTOR_LOG_FILE="$LOG_DIR/${CONNECTOR_NAME}.log"
JAVA_PROCESS_NAME="pivotal-gin-big-bank-java-connector-${WALLET}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

JAR_DIR="$BIGBANK_CONNECTOR_HOME/implementation/mod_pivotal_connector_api/target"
JAR_FILE="$JAR_DIR/pivotal_connector_api.jar"

if [ ! -f "$JAR_FILE" ]; then
  (
    cd "$BIGBANK_CONNECTOR_HOME"
    JAVA_HOME="$JDK_HOME" PATH="$JDK_HOME/bin:$MAVEN_HOME/bin:$PATH" \
      "$MAVEN_HOME/bin/mvn" -DskipTests package
  )
fi

stop_pid_file() {
  local pid_file="$1"
  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    kill "$(cat "$pid_file")"
    sleep 1
  fi
}

stop_pid_file "$CONNECTOR_PID_FILE"

if pgrep -f "^pivotal-connector-nestjs-${WALLET} " >/dev/null 2>&1; then
  pgrep -f "^pivotal-connector-nestjs-${WALLET} " | xargs -r kill
  sleep 1
fi

if pgrep -f "^${JAVA_PROCESS_NAME} " >/dev/null 2>&1; then
  pgrep -f "^${JAVA_PROCESS_NAME} " | awk 'NR==1 {print $1}' > "$CONNECTOR_PID_FILE"
  echo "$CONNECTOR_NAME already running with Java BigBank connector"
  exit 0
fi

if ! curl -sS -X POST "$BIGBANK_MOCK_URL/auth/token" \
  -H 'content-type: application/json' \
  -d '{"expires_in":3600}' >/dev/null 2>&1; then
  : >"$BIGBANK_MOCK_LOG_FILE"
  setsid -f "$NODE_HOME/bin/node" "$LOCAL_HOME/scripts/tmp/pivotal-bigbank-mock.mjs" \
    >"$BIGBANK_MOCK_LOG_FILE" 2>&1 < /dev/null
  sleep 1
fi

curl -sS -X POST "$BIGBANK_MOCK_URL/auth/token" \
  -H 'content-type: application/json' \
  -d '{"expires_in":3600}' >/dev/null
pgrep -f "pivotal-bigbank-mock.mjs" | awk 'NR==1 {print $1}' > "$BIGBANK_MOCK_PID_FILE" || true

set -a
source "$ENV_FILE"
set +a

: >"$CONNECTOR_LOG_FILE"
(
  cd "$JAR_DIR"
  setsid -f env JAVA_HOME="$JDK_HOME" PATH="$JDK_HOME/bin:$PATH" \
    bash -c 'exec -a "$0" "$@"' "$JAVA_PROCESS_NAME" "$JDK_HOME/bin/java" \
      -DoutboundEndpoint="${OUTBOUND_ENDPOINT:-http://127.0.0.1:4001}" \
      -DdfspLocale="${DFSP_LOCALE:-en}" \
      -DpublicKey="${PUBLIC_KEY:-}" \
      -DfspConnectorPortNo="${FSP_CONNECTOR_PORT_NO:-18082}" \
      -DdecimalPlaces="${DECIMAL_PLACES:-2}" \
      -DprefixOracleEndpoint="${PREFIX_ORACLE_ENDPOINT:-http://127.0.0.1}" \
      -DfspId="${CONNECTOR_ID}" \
      -DbackendEndpoint="${BIGBANK_MOCK_URL}" \
      -DfeeEngineEndpoint="${BIGBANK_MOCK_URL}" \
      -DsupportedCurrencies="${CONNECTOR_SUPPORTED_CURRENCIES}" \
      -DisPrefix="${IS_PREFIX:-false}" \
      -DexpiresIn="${EXPIRES_IN:-3600}" \
      -DclientId="${CLIENT_ID:-local-client}" \
      -DclientSecret="${CLIENT_SECRET:-local-secret}" \
      -DrefreshTime="${REFRESH_TIME:-300}" \
      -DsdkConnectorPortNo="${SDK_CONNECTOR_PORT_NO:-18082}" \
      -DconnectorId="${CONNECTOR_ID}" \
      -DconnectorIlpSecret="${CONNECTOR_ILP_SECRET}" \
      -DnatsUrl="${NATS_URL}" \
      -DfspiopStreamName="${PIVOTAL_FSPIOP_STREAM_NAME:-PAYPORT_FSPIOP}" \
      -DpivotalAuditStreamName="${PIVOTAL_AUDIT_STREAM_NAME:-PAYPORT_AUDIT}" \
      -DconnectorForcePatchError="${CONNECTOR_FORCE_PATCH_ERROR:-false}" \
      -DfspiopPartiesUrl="${FSPIOP_PARTIES_URL}" \
      -DfspiopQuotesUrl="${FSPIOP_QUOTES_URL}" \
      -DfspiopTransfersUrl="${FSPIOP_TRANSFERS_URL}" \
      -DfspiopSwitchId="${FSPIOP_SWITCH_ID}" \
      -DredisUrl="${REDIS_URL:-redis://127.0.0.1:6379}" \
      -DredisTtlSeconds="${REDIS_TTL_SECONDS:-1200}" \
      -DbackendApiTimeoutMs="${BACKEND_API_TIMEOUT_MS:-30000}" \
      -DtransactionAmountLimit="${TRANSACTION_AMOUNT_LIMIT:-0}" \
      -cp "pivotal_connector_api.jar:lib/*" \
      com.thitsaworks.mojaloop.coreconnector.PivotalCoreConnectorApplication \
    >"$CONNECTOR_LOG_FILE" 2>&1 < /dev/null
)

for _ in $(seq 1 60); do
  if pgrep -f "^${JAVA_PROCESS_NAME} " >/dev/null 2>&1; then
    pgrep -f "^${JAVA_PROCESS_NAME} " | awk 'NR==1 {print $1}' > "$CONNECTOR_PID_FILE" || true
    if rg -q "Started PivotalCoreConnectorApplication|Listening on 'fspiop\\.wallet2\\.get\\.parties'" "$CONNECTOR_LOG_FILE"; then
      echo "$CONNECTOR_NAME running with Java BigBank connector"
      exit 0
    fi
  else
    echo "$CONNECTOR_NAME exited during startup; see $CONNECTOR_LOG_FILE" >&2
    exit 1
  fi
  sleep 1
done

echo "$CONNECTOR_NAME did not become ready; see $CONNECTOR_LOG_FILE" >&2
exit 1
