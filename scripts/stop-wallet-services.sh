#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

stop_named_process wallet1-connector "$RUN_DIR/wallet1-connector.pid" "" '(samples-wallet1-connector|dist/packages/samples/wallet1-connector/main)'
stop_named_process wallet2-connector "$RUN_DIR/wallet2-connector.pid" "" '(samples-wallet2-connector|dist/packages/samples/wallet2-connector/main)'

# The MTPA web inbound/outbound apps are shared by wallet1 and wallet2.
stop_named_process wallet-web-inbound "$RUN_DIR/wallet1-web-inbound.pid" 3201 '(apps-web-inbound|dist/packages/apps/web-inbound/main)'
stop_named_process wallet-web-inbound "$RUN_DIR/wallet2-web-inbound.pid" 3201 '(apps-web-inbound|dist/packages/apps/web-inbound/main)'
stop_named_process wallet-web-outbound "$RUN_DIR/wallet1-web-outbound.pid" 3200 '(apps-web-outbound|dist/packages/apps/web-outbound/main)'
stop_named_process wallet-web-outbound "$RUN_DIR/wallet2-web-outbound.pid" 3200 '(apps-web-outbound|dist/packages/apps/web-outbound/main)'
