#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

usage() {
  cat <<'EOF'
Usage:
  local/scripts/generate-pivotal-access-keypair.sh <fsp-id> [output-dir]

Examples:
  local/scripts/generate-pivotal-access-keypair.sh wallet1
  local/scripts/generate-pivotal-access-keypair.sh wallet2 /tmp/pivotal-keys

Output:
  <fsp-id>-access-private-key.pem  Use this private key in Postman signing.
  <fsp-id>-access-public-key.pem   Paste this public key into Pivotal "Update access key".

Environment:
  PIVOTAL_ACCESS_KEY_BITS=2048      RSA key size.
  PIVOTAL_ACCESS_KEY_OVERWRITE=1    Replace existing files.
EOF
}

fsp_id="${1:-}"
output_dir="${2:-$CONF_DIR/access-keys}"
key_bits="${PIVOTAL_ACCESS_KEY_BITS:-2048}"

if [ -z "$fsp_id" ] || [ "$fsp_id" = "--help" ] || [ "$fsp_id" = "-h" ]; then
  usage
  exit 0
fi

case "$fsp_id" in
  *[!A-Za-z0-9._-]*)
    echo "Invalid fsp-id: use only letters, digits, dot, underscore, or hyphen." >&2
    exit 1
    ;;
esac

case "$key_bits" in
  2048|3072|4096)
    ;;
  *)
    echo "Invalid PIVOTAL_ACCESS_KEY_BITS=$key_bits. Use 2048, 3072, or 4096." >&2
    exit 1
    ;;
esac

mkdir -p "$output_dir"

private_key="$output_dir/${fsp_id}-access-private-key.pem"
public_key="$output_dir/${fsp_id}-access-public-key.pem"

if [ "${PIVOTAL_ACCESS_KEY_OVERWRITE:-0}" != "1" ]; then
  for file in "$private_key" "$public_key"; do
    if [ -e "$file" ]; then
      echo "Refusing to overwrite existing file: $file" >&2
      echo "Set PIVOTAL_ACCESS_KEY_OVERWRITE=1 to replace it." >&2
      exit 1
    fi
  done
fi

old_umask="$(umask)"
umask 077
openssl genpkey \
  -algorithm RSA \
  -pkeyopt "rsa_keygen_bits:$key_bits" \
  -out "$private_key" >/dev/null 2>&1
umask "$old_umask"

openssl rsa -pubout -in "$private_key" -out "$public_key" >/dev/null 2>&1
chmod 600 "$private_key"
chmod 644 "$public_key"

cat <<EOF
Generated Pivotal access keypair for: $fsp_id

Private key for Postman:
  $private_key

Public key to paste into Pivotal UI:
  $public_key

After saving the public key in Pivotal, wait for web-outbound key refresh:
  PARTICIPANT_KEY_STORE_REFRESH_INTERVAL_SECONDS=5

Quick view public key:
  sed -n '1,\$p' "$public_key"
EOF
