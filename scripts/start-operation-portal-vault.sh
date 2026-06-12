#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/operation-portal-common.sh"

operation_portal_init

if ! command -v docker >/dev/null 2>&1; then
  echo "Operation portal local Vault requires Docker on PATH." >&2
  exit 1
fi

vault_host_port="${OPERATION_PORTAL_VAULT_ADDR##*:}"

if docker ps --format '{{.Names}}' | grep -qx "$OPERATION_PORTAL_VAULT_CONTAINER"; then
  echo "operation-portal-vault: already running"
elif docker ps -a --format '{{.Names}}' | grep -qx "$OPERATION_PORTAL_VAULT_CONTAINER"; then
  docker start "$OPERATION_PORTAL_VAULT_CONTAINER" >/dev/null
  echo "operation-portal-vault: started existing container"
else
  docker run -d \
    --name "$OPERATION_PORTAL_VAULT_CONTAINER" \
    -p "127.0.0.1:${vault_host_port}:8200" \
    -e "VAULT_DEV_ROOT_TOKEN_ID=$OPERATION_PORTAL_VAULT_TOKEN" \
    -e "VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200" \
    "$OPERATION_PORTAL_VAULT_IMAGE" \
    server -dev >/dev/null
  echo "operation-portal-vault: started new container"
fi

for _ in $(seq 1 60); do
  if curl -fsS --max-time 2 "$OPERATION_PORTAL_VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker exec \
  -e "VAULT_ADDR=http://127.0.0.1:8200" \
  -e "VAULT_TOKEN=$OPERATION_PORTAL_VAULT_TOKEN" \
  "$OPERATION_PORTAL_VAULT_CONTAINER" \
  vault secrets enable -path="$OPERATION_PORTAL_ENGINE_PATH" -version=2 kv >/dev/null 2>&1 || true

put_secret() {
  local path="$1"
  docker exec -i \
    -e "VAULT_ADDR=http://127.0.0.1:8200" \
    -e "VAULT_TOKEN=$OPERATION_PORTAL_VAULT_TOKEN" \
    "$OPERATION_PORTAL_VAULT_CONTAINER" \
    sh -c "cat > /tmp/secret.json && vault kv put '$OPERATION_PORTAL_ENGINE_PATH/$path' @/tmp/secret.json >/dev/null"
}

put_secret "redis/settings" <<EOF
{"redisUrl":"$OPERATION_PORTAL_REDIS_URL"}
EOF

put_secret "mysql/portal_data/flyway/settings" <<EOF
{
  "locations":["classpath:db/core"],
  "url":"jdbc:mysql://$OPERATION_PORTAL_DB_HOST:$OPERATION_PORTAL_DB_PORT/$OPERATION_PORTAL_DB_NAME?createDatabaseIfNotExist=true",
  "username":"$OPERATION_PORTAL_DB_FLYWAY_USERNAME",
  "password":"$OPERATION_PORTAL_DB_FLYWAY_PASSWORD"
}
EOF

put_secret "mysql/portal_data/write_db/settings" <<EOF
{
  "url":"jdbc:mysql://$OPERATION_PORTAL_DB_HOST:$OPERATION_PORTAL_DB_PORT/$OPERATION_PORTAL_DB_NAME",
  "username":"$OPERATION_PORTAL_DB_USERNAME",
  "password":"$OPERATION_PORTAL_DB_PASSWORD",
  "minPoolSize":$OPERATION_PORTAL_DB_POOL_MIN,
  "maxPoolSize":$OPERATION_PORTAL_DB_POOL_MAX
}
EOF

put_secret "mysql/portal_data/read_db/settings" <<EOF
{
  "url":"jdbc:mysql://$OPERATION_PORTAL_DB_HOST:$OPERATION_PORTAL_DB_PORT/$OPERATION_PORTAL_DB_NAME",
  "username":"$OPERATION_PORTAL_DB_READ_USERNAME",
  "password":"$OPERATION_PORTAL_DB_READ_PASSWORD",
  "minPoolSize":$OPERATION_PORTAL_DB_POOL_MIN,
  "maxPoolSize":$OPERATION_PORTAL_DB_POOL_MAX
}
EOF

put_secret "mysql/hub_data/write_db/settings" <<EOF
{
  "url":"jdbc:mysql://$OPERATION_PORTAL_HUB_DB_HOST:$OPERATION_PORTAL_HUB_DB_PORT/$OPERATION_PORTAL_HUB_DB_NAME",
  "username":"$OPERATION_PORTAL_HUB_DB_USERNAME",
  "password":"$OPERATION_PORTAL_HUB_DB_PASSWORD",
  "minPoolSize":$OPERATION_PORTAL_HUB_DB_POOL_MIN,
  "maxPoolSize":$OPERATION_PORTAL_HUB_DB_POOL_MAX
}
EOF

put_secret "mysql/hub_data/read_db/settings" <<EOF
{
  "url":"jdbc:mysql://$OPERATION_PORTAL_HUB_DB_HOST:$OPERATION_PORTAL_HUB_DB_PORT/$OPERATION_PORTAL_HUB_DB_NAME",
  "username":"$OPERATION_PORTAL_HUB_DB_USERNAME",
  "password":"$OPERATION_PORTAL_HUB_DB_PASSWORD",
  "minPoolSize":$OPERATION_PORTAL_HUB_DB_POOL_MIN,
  "maxPoolSize":$OPERATION_PORTAL_HUB_DB_POOL_MAX
}
EOF

put_secret "mongo/hub_data/write_db/settings" <<EOF
{
  "uri":"$OPERATION_PORTAL_MONGO_URI",
  "database":"$OPERATION_PORTAL_MONGO_DATABASE",
  "minPoolSize":0,
  "maxPoolSize":10,
  "maxWaitMs":120000,
  "connectTimeoutMs":10000,
  "readTimeoutMs":0,
  "retryWrites":false,
  "readPreference":"primary"
}
EOF

put_secret "mongo/hub_data/read_db/settings" <<EOF
{
  "uri":"$OPERATION_PORTAL_MONGO_URI",
  "database":"$OPERATION_PORTAL_MONGO_DATABASE",
  "minPoolSize":0,
  "maxPoolSize":10,
  "maxWaitMs":120000,
  "connectTimeoutMs":10000,
  "readTimeoutMs":0,
  "retryWrites":false,
  "readPreference":"$OPERATION_PORTAL_MONGO_READ_PREFERENCE"
}
EOF

put_secret "s3/settings" <<EOF
{
  "enabled":$OPERATION_PORTAL_S3_ENABLED,
  "bucket":"$OPERATION_PORTAL_S3_BUCKET",
  "accessKey":"$OPERATION_PORTAL_S3_ACCESS_KEY",
  "secretKey":"$OPERATION_PORTAL_S3_SECRET_KEY",
  "region":"$OPERATION_PORTAL_S3_REGION",
  "prefix":"$OPERATION_PORTAL_S3_PREFIX",
  "endpoint":"$OPERATION_PORTAL_S3_ENDPOINT",
  "pathStyleAccess":$OPERATION_PORTAL_S3_PATH_STYLE_ACCESS,
  "presignedUrlLifetime":"$OPERATION_PORTAL_S3_PRESIGNED_URL_LIFETIME"
}
EOF

echo "operation-portal-vault: seeded $OPERATION_PORTAL_ENGINE_PATH"
