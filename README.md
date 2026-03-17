# Local Mojaloop Bootstrap

This repository is not standalone.

`local/env.sh` sets `ROOT_DIR` to the parent directory of this repository, so the bootstrap expects a shared workspace layout with this repo and the service repos cloned side-by-side.

All commands below are run from `ROOT_DIR`, which is the parent directory of `local/`, not from inside `local/` itself.

Expected workspace layout:

```text
<workspace>/
  local/
  central-ledger/
  account-lookup-service/
  ml-api-adapter/
  quoting-service/
  central-settlement/
  mtpa/                       # optional, only needed for wallet DFSP flows
  tools/
  runtime-root/
```

Required sibling repos for the core stack:

- `central-ledger`
- `account-lookup-service`
- `ml-api-adapter`
- `quoting-service`
- `central-settlement`

Additional sibling repo for the wallet DFSP flows in this README:

- `mtpa`

Example clone layout:

```bash
mkdir -p ~/work/mojaloop
cd ~/work/mojaloop

git clone --branch codex/mojaloop-local https://github.com/tw-sithumyo/mojaloop-local-deployment.git local
git clone https://github.com/mojaloop/central-ledger.git central-ledger
git clone https://github.com/mojaloop/account-lookup-service.git account-lookup-service
git clone --branch codex/mojaloop-local https://github.com/tw-sithumyo/ml-api-adapter.git ml-api-adapter
git clone https://github.com/mojaloop/quoting-service.git quoting-service
git clone https://github.com/mojaloop/central-settlement.git central-settlement
git clone --branch codex/mojaloop-local https://github.com/tw-sithumyo/mtpa.git mtpa
```

This directory contains a non-container bootstrap for a minimal Mojaloop core stack in that workspace.

Order:

1. `source local/env.sh`
2. `local/scripts/start-infra.sh`
3. `local/scripts/npm-ci-all.sh`
4. `local/scripts/migrate-all.sh`
5. `local/scripts/start-services.sh`

Optional `wallet1` DFSP bootstrap with `mtpa`:

6. `local/scripts/setup-wallet1.sh`
7. `local/scripts/test-wallet1-flow.sh`

Optional `wallet2` DFSP bootstrap and inter-DFSP test:

8. `local/scripts/setup-wallet2.sh`
9. `local/scripts/test-wallet1-wallet2-flow.sh`

Stop commands:

- stop the local web UI: `local/scripts/stop-ui.sh`
- stop core services: `local/scripts/stop-services.sh`
- stop wallet-side MTPA services: `local/scripts/stop-wallet-services.sh`
- stop infra: `local/scripts/stop-infra.sh`
- stop everything: `local/scripts/stop-all.sh`

Optional local UI:

- start: `local/scripts/start-ui.sh`
- stop: `local/scripts/stop-ui.sh`
- URL: `http://127.0.0.1:3400`

The UI is read-only. It shows:

- service and infra up/down state
- HTTP health checks where available
- current log tail for the selected component

The `wallet1` flow is intentionally minimal for now:

- it uses `mtpa` as the DFSP app layer
- it starts a local `nats-server` with JetStream
- it creates the required `PAYPORT_FSPIOP` and `PAYPORT_AUDIT` streams
- it onboards `wallet1` into Central Ledger
- it enables on-us transfers in local `central-ledger` so a single-DFSP self-flow can complete
- it verifies a self-flow using `lookup -> quote -> transfer`

Current limitation:

- `mtpa` outbound lookup currently requires `destination`, so the first-cut `wallet1` test flow is a directed lookup to `wallet1` rather than an oracle-driven party discovery flow
- the `wallet1 -> wallet2` test flow is also a directed lookup, but it exercises a real cross-DFSP `lookup -> quote -> transfer` path with distinct parties
