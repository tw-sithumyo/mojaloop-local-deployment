#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

usage() {
  cat <<'EOF'
Usage:
  local/scripts/sign-pivotal-access-jwt.sh <private-key.pem> <payload.json|->

Examples:
  local/scripts/sign-pivotal-access-jwt.sh local/config/access-keys/wallet1-access-private-key.pem /tmp/sendmoney.json
  printf '{"date":"Thu, 25 Jun 2026 04:00:00 GMT"}' | local/scripts/sign-pivotal-access-jwt.sh key.pem -

Notes:
  web-outbound expects the raw JWT in the "authorization" header.
  For POST/PUT with a JSON body, the JWT payload must be the same JSON object as the request body.
  For requests without a body, sign {"date":"<same date header value>"}.
EOF
}

private_key="${1:-}"
payload_file="${2:-}"

if [ -z "$private_key" ] || [ "$private_key" = "--help" ] || [ "$private_key" = "-h" ]; then
  usage
  exit 0
fi

if [ -z "$payload_file" ]; then
  usage >&2
  exit 1
fi

if [ ! -f "$private_key" ]; then
  echo "Private key file not found: $private_key" >&2
  exit 1
fi

if [ "$payload_file" = "-" ]; then
  payload_json="$(cat)"
else
  if [ ! -f "$payload_file" ]; then
    echo "Payload file not found: $payload_file" >&2
    exit 1
  fi
  payload_json="$(cat "$payload_file")"
fi

JWT_PAYLOAD="$payload_json" node - "$private_key" <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');

const privateKeyPath = process.argv[2];

const toBase64Url = (value) => Buffer.from(value, 'utf8').toString('base64url');

const privateKey = fs.readFileSync(privateKeyPath);
const payload = JSON.parse(process.env.JWT_PAYLOAD ?? '');

if (payload == null || typeof payload !== 'object' || Array.isArray(payload)) {
  throw new Error('JWT payload must be a JSON object.');
}

const header = {alg: 'RS256', typ: 'JWT', cty: 'json'};
const signingInput = `${toBase64Url(JSON.stringify(header))}.${toBase64Url(JSON.stringify(payload))}`;
const signature = crypto
  .sign('RSA-SHA256', Buffer.from(signingInput, 'utf8'), privateKey)
  .toString('base64url');

process.stdout.write(`${signingInput}.${signature}\n`);
NODE
