#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

stop_named_process wallet1-demowallet "$RUN_DIR/wallet1-demowallet.pid" 8081 'DemowalletPortNo=8081.*com.thitsaworks.demowallet.DemoWalletApplication'
stop_named_process wallet2-demowallet "$RUN_DIR/wallet2-demowallet.pid" 8082 'DemowalletPortNo=8082.*com.thitsaworks.demowallet.DemoWalletApplication'
