#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/operation-portal-common.sh"

operation_portal_init

"$RUNTIME_ROOT/usr/bin/mariadb" -h "$OPERATION_PORTAL_DB_HOST" -P "$OPERATION_PORTAL_DB_PORT" -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`$OPERATION_PORTAL_DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$OPERATION_PORTAL_DB_USERNAME'@'127.0.0.1' IDENTIFIED BY '$OPERATION_PORTAL_DB_PASSWORD';
CREATE USER IF NOT EXISTS '$OPERATION_PORTAL_DB_USERNAME'@'localhost' IDENTIFIED BY '$OPERATION_PORTAL_DB_PASSWORD';
CREATE USER IF NOT EXISTS '$OPERATION_PORTAL_DB_READ_USERNAME'@'127.0.0.1' IDENTIFIED BY '$OPERATION_PORTAL_DB_READ_PASSWORD';
CREATE USER IF NOT EXISTS '$OPERATION_PORTAL_DB_READ_USERNAME'@'localhost' IDENTIFIED BY '$OPERATION_PORTAL_DB_READ_PASSWORD';
GRANT ALL PRIVILEGES ON \`$OPERATION_PORTAL_DB_NAME\`.* TO '$OPERATION_PORTAL_DB_USERNAME'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`$OPERATION_PORTAL_DB_NAME\`.* TO '$OPERATION_PORTAL_DB_USERNAME'@'localhost';
GRANT SELECT ON \`$OPERATION_PORTAL_DB_NAME\`.* TO '$OPERATION_PORTAL_DB_READ_USERNAME'@'127.0.0.1';
GRANT SELECT ON \`$OPERATION_PORTAL_DB_NAME\`.* TO '$OPERATION_PORTAL_DB_READ_USERNAME'@'localhost';
FLUSH PRIVILEGES;
SQL

"$LOCAL_HOME/scripts/start-operation-portal-vault.sh"

if [ ! -f "$OPERATION_PORTAL_JAR" ]; then
  maven_env=(env "JAVA_HOME=$JDK_HOME" "PATH=$JDK_HOME/bin:$PATH")
  "${maven_env[@]}" "$MAVEN_HOME/bin/mvn" -B -ntp clean -f "$OPERATION_PORTAL_HOME/implementation/component/mod_fspiop" -P local install
  "${maven_env[@]}" "$MAVEN_HOME/bin/mvn" -B -ntp clean -f "$OPERATION_PORTAL_HOME/implementation" -DskipTests -P local install
  "${maven_env[@]}" "$MAVEN_HOME/bin/mvn" -B -ntp clean -f "$OPERATION_PORTAL_HOME/implementation/web_api_operation" -DskipTests -P local install
fi

if [ -f "$OPERATION_PORTAL_PID_FILE" ] && kill -0 "$(cat "$OPERATION_PORTAL_PID_FILE")" 2>/dev/null; then
  echo "operation-portal: already running pid $(cat "$OPERATION_PORTAL_PID_FILE")"
  exit 0
fi

target_dir="$OPERATION_PORTAL_HOME/implementation/web_api_operation/target"

(
  cd "$target_dir"
  setsid -f "$JDK_HOME/bin/java" \
    "-DVAULT_ADDR=$OPERATION_PORTAL_VAULT_ADDR" \
    "-DVAULT_TOKEN=$OPERATION_PORTAL_VAULT_TOKEN" \
    "-DENGINE_PATH=$OPERATION_PORTAL_ENGINE_PATH" \
    "-DOPERATION_PORTAL_PORT_NO=$OPERATION_PORTAL_PORT" \
    "-DCENTRAL_LEDGER_ENDPOINT=http://127.0.0.1:3001" \
    "-DSETTLEMENT_ENDPOINT=http://127.0.0.1:3007" \
    "-DOPERATION_PORTAL_FRONTEND_ENDPOINT=$OPERATION_PORTAL_FRONTEND_ENDPOINT" \
    "-DREPORT_PAGE_SIZE=$OPERATION_PORTAL_REPORT_PAGE_SIZE" \
    -cp "operation_api.jar:lib/*" \
    com.thitsaworks.operation_portal.api.operation.portal.WebApiOperationPortalApplication \
    >"$OPERATION_PORTAL_LOG_FILE" 2>&1 < /dev/null
)

for _ in $(seq 1 60); do
  pid="$(pgrep -f 'operation_api\.jar:lib/\*.*WebApiOperationPortalApplication' | head -n 1 || true)"
  if [ -n "$pid" ]; then
    echo "$pid" > "$OPERATION_PORTAL_PID_FILE"
  fi

  if curl -fsS --max-time 2 "http://127.0.0.1:$OPERATION_PORTAL_PORT/actuator/health" >/dev/null 2>&1; then
    echo "operation-portal: http://127.0.0.1:$OPERATION_PORTAL_PORT"
    exit 0
  fi
  sleep 1
done

echo "operation-portal: failed to become healthy; see $OPERATION_PORTAL_LOG_FILE" >&2
exit 1
