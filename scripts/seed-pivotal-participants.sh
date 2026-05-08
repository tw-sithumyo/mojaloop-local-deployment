#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

if [ ! -d "$PIVOTAL_HOME/node_modules" ]; then
  "$LOCAL_HOME/scripts/npm-ci-pivotal.sh"
fi

participants=()

for env_file in "$CONF_DIR/wallet1-pivotal.env" "$CONF_DIR/wallet2-pivotal.env"; do
  if [ ! -f "$env_file" ]; then
    continue
  fi

  connector_id="$(
    set -a
    source "$env_file"
    set +a
    printf '%s' "${CONNECTOR_ID:-}"
  )"

  if [ -n "$connector_id" ]; then
    participants+=("$connector_id")
  fi
done

if [ "${#participants[@]}" -eq 0 ]; then
  exit 0
fi

PIVOTAL_PARTICIPANTS="$(IFS=,; echo "${participants[*]}")" "$NODE_HOME/bin/node" <<'NODE'
const { generateKeyPairSync } = require('node:crypto');
const mysql = require(`${process.env.PIVOTAL_HOME}/node_modules/mysql2/promise`);

const names = [...new Set((process.env.PIVOTAL_PARTICIPANTS ?? '').split(',').map((value) => value.trim()).filter(Boolean))];

if (names.length === 0) {
  process.exit(0);
}

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const publicPem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
const privatePem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();

const main = async () => {
  const connection = await mysql.createConnection({
    host: process.env.PIVOTAL_DB_HOST ?? '127.0.0.1',
    port: Number(process.env.PIVOTAL_DB_PORT ?? '3306'),
    user: process.env.PIVOTAL_DB_USERNAME ?? 'pivotal',
    password: process.env.PIVOTAL_DB_PASSWORD ?? 'password',
    database: process.env.PIVOTAL_DB_NAME ?? 'pivotal',
  });

  try {
    for (const name of names) {
      await connection.execute(
        `INSERT INTO participant (name, jws_public_key, jws_private_key, access_public_key)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           jws_public_key = VALUES(jws_public_key),
           jws_private_key = VALUES(jws_private_key),
           access_public_key = VALUES(access_public_key)`,
        [name, publicPem, privatePem, publicPem],
      );
    }
  } finally {
    await connection.end();
  }
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
