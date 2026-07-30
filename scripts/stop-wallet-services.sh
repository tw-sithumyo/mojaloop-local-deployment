#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-common.sh"

stop_named_process wallet1-sdk "$RUN_DIR/wallet1-sdk.pid" 3200 '(sdk-scheme-adapter.*modules-api-svc:start|node .*modules/api-svc/src/index.js)'
stop_named_process wallet2-sdk "$RUN_DIR/wallet2-sdk.pid" 3210 '(sdk-scheme-adapter.*modules-api-svc:start|node .*modules/api-svc/src/index.js)'
stop_named_process wallet1-cc "$RUN_DIR/wallet1-cc.pid" 3303 'FspConnectorApiApplication'
stop_named_process wallet2-cc "$RUN_DIR/wallet2-cc.pid" 3304 'FspConnectorApiApplication'
stop_named_process wallet1-backend "$RUN_DIR/wallet1-backend.pid" 3403 'thitsawallet-backend.mjs'
stop_named_process wallet2-backend "$RUN_DIR/wallet2-backend.pid" 3404 'thitsawallet-backend.mjs'

"$LOCAL_HOME/scripts/stop-pivotal-connector-services.sh" || true
"$LOCAL_HOME/scripts/stop-pivotal-portal-services.sh" || true
"$LOCAL_HOME/scripts/stop-pivotal-auditor.sh" || true
stop_named_process wallet1-connector "$RUN_DIR/wallet1-connector.pid" "" '(samples-wallet1-connector|dist/packages/samples/wallet1-connector/main)'
stop_named_process wallet2-connector "$RUN_DIR/wallet2-connector.pid" "" '(samples-wallet2-connector|dist/packages/samples/wallet2-connector/main)'
"$LOCAL_HOME/scripts/stop-demowallet-services.sh" || true

# The Pivotal web inbound/outbound apps are shared by wallet1 and wallet2.
stop_named_process wallet-web-inbound "$RUN_DIR/wallet1-web-inbound.pid" 3201 '(apps-web-inbound|dist/packages/apps/web-inbound/main)'
stop_named_process wallet-web-inbound "$RUN_DIR/wallet2-web-inbound.pid" 3201 '(apps-web-inbound|dist/packages/apps/web-inbound/main)'
stop_named_process wallet-web-outbound "$RUN_DIR/wallet1-web-outbound.pid" 3200 '(apps-web-outbound|dist/packages/apps/web-outbound/main)'
stop_named_process wallet-web-outbound "$RUN_DIR/wallet2-web-outbound.pid" 3200 '(apps-web-outbound|dist/packages/apps/web-outbound/main)'
