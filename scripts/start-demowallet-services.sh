#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

TARGET="${1:-all}"
APP_DIR="$DEMOWALLET_HOME/implementation/web_demowallet_api/target"
JAR="$APP_DIR/demowallet_api.jar"

if [ ! -f "$JAR" ] || [ ! -d "$APP_DIR/lib" ]; then
  "$LOCAL_HOME/scripts/build-demowallet.sh"
fi

"$LOCAL_HOME/scripts/init-demowallet-db.sh"

start_demowallet() {
  local wallet="$1"
  local port="$2"
  local schema="$3"
  local name="${wallet}-demowallet"
  local pattern="DemowalletPortNo=${port}.*com.thitsaworks.demowallet.DemoWalletApplication"

  if ss -ltn | rg -q "[:.]$port\\b"; then
    pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$RUN_DIR/$name.pid" || true
    return
  fi

  if pgrep -af "$pattern" >/dev/null 2>&1; then
    pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$RUN_DIR/$name.pid" || true
    return
  fi

  (
    cd "$APP_DIR"
    : >"$LOG_DIR/$name.log"
    setsid -f env \
      JAVA_HOME="$DEMOWALLET_JAVA_HOME" \
      PATH="$DEMOWALLET_JAVA_HOME/bin:$PATH" \
      java \
      "-DDataSourceUrl=jdbc:mysql://127.0.0.1:3306/${schema}" \
      "-DDataSourceUsername=central_ledger" \
      "-DDataSourcePassword=password" \
      "-DMojaloopApiUrl=http://127.0.0.1:3200/secured/sendmoney" \
      "-DMojaloopCcVnowApiUrl=http://127.0.0.1:3200/secured/sendmoney" \
      "-DPrefixOracleUrl=http://127.0.0.1" \
      "-DMojaloopThitsaconnectApiUrl=http://127.0.0.1:3200/secured/sendmoney" \
      "-DThitsanetApiUrl=http://127.0.0.1" \
      "-DThitsaXWaveApiUrl=http://127.0.0.1" \
      "-DDemowalletPortNo=${port}" \
      "-DPrivateKey=test_private_key" \
      "-DisPrefix=false" \
      "-DFeePercentage=0.01" \
      -cp "demowallet_api.jar:lib/*" \
      com.thitsaworks.demowallet.DemoWalletApplication \
      >"$LOG_DIR/$name.log" 2>&1 < /dev/null
  )

  for _ in $(seq 1 90); do
    if curl -fsS "http://127.0.0.1:${port}/public/heart_beat" >/dev/null 2>&1; then
      pgrep -af "$pattern" | awk 'NR==1 {print $1}' > "$RUN_DIR/$name.pid" || true
      return
    fi
    sleep 1
  done

  echo "$name did not start listening on port $port" >&2
  exit 1
}

case "$TARGET" in
  all)
    start_demowallet wallet1 8081 wallet1
    start_demowallet wallet2 8082 wallet2
    ;;
  wallet1)
    start_demowallet wallet1 8081 wallet1
    ;;
  wallet2)
    start_demowallet wallet2 8082 wallet2
    ;;
  *)
    echo "Usage: $0 [all|wallet1|wallet2]" >&2
    exit 1
    ;;
esac
