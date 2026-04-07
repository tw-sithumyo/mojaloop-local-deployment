# Local Mojaloop Bootstrap

This repository is not standalone.

`local/env.sh` sets `ROOT_DIR` to the parent directory of this repository, so the bootstrap expects a shared workspace layout with this repo and the service repos cloned side-by-side.

All commands below are run from `ROOT_DIR`, which is the parent directory of `local/`, not from inside `local/` itself.

Tool prerequisites:

- Node.js and `npm`
  - expected under `tools/node-v22.22.0-linux-x64`
- Java runtime
  - expected under `tools/jdk-21.0.10+7-jre`
- Kafka binaries
  - expected under `tools/kafka_2.13-3.9.1`
- Docker engine
  - used by the optional managed MongoDB helper for `reporting-aggregator-svc`
- Local runtime binaries for infra
  - expected under `runtime-root/usr/bin`
  - used for `mariadbd`, `mariadb-admin`, and `valkey-server`
- Standard shell tools available on the machine
  - `git`, `curl`, `tar`, `ss`, `pgrep`, `awk`, `setsid`, `rg`

After `source local/env.sh`, the bootstrap scripts prefer these workspace-local tool paths over system-wide installs.

If `tools/` is empty, install the expected workspace-local toolchain with:

```bash
local/scripts/install-tools.sh
```

This installs:

- Node.js + `npm`
- Java runtime
- Kafka
- NATS server

It does not build `runtime-root/`; that still needs to exist separately for MariaDB and Valkey binaries.

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
  reporting-aggregator-svc/         # optional, only needed for local reporting
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

Additional optional repo:

- `reporting-aggregator-svc`

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
git clone https://github.com/mojaloop/reporting-aggregator-svc.git reporting-aggregator-svc
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

## Local UI

Useful commands:

```bash
local/scripts/start-ui.sh
local/scripts/stop-ui.sh
```

URL:

- `http://127.0.0.1:3400`

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

## Reporting Aggregator

The reporting stack is optional and separate from the main Mojaloop bootstrap.

It consists of:

- `reporting-aggregator-svc` as a host process
- MariaDB from the existing local Mojaloop infra
- MongoDB as the reporting target

Useful commands:

```bash
local/scripts/npm-ci-reporting-aggregator.sh
local/scripts/start-reporting-stack.sh
local/scripts/status-reporting-stack.sh
local/scripts/logs-reporting-aggregator.sh
local/scripts/stop-reporting-stack.sh
```

Default config lives in `local/config/reporting-aggregator.env`.

The scripts look for the service repo in:

- `$REPORTING_AGGREGATOR_HOME`
- `reporting-aggregator-svc`

Default local wiring:

- source MySQL: `127.0.0.1:3306`, schema `central_ledger`
- target MongoDB: `127.0.0.1:27017`, database `reporting`

Managed MongoDB:

- set `REPORTING_MONGO_MANAGED=1` in `local/config/reporting-aggregator.env`
- this makes `start-reporting-stack.sh` run a local MongoDB Docker container
- if left at `0`, the scripts expect MongoDB to already be running elsewhere

Service requirements:

- hard requirement to start: MySQL plus MongoDB
- meaningful transfer data: `central-ledger`, `quoting-service`, and actual transfer traffic
- meaningful settlement data: settlement flows populating settlement tables
- meaningful FX data: FX flows populating `fxTransfer*` and related tables

## Stop Commands

- stop the local web UI: `local/scripts/stop-ui.sh`
- stop the reporting stack: `local/scripts/stop-reporting-stack.sh`
- stop wallet-side MTPA services: `local/scripts/stop-wallet-services.sh`
- stop core services: `local/scripts/stop-services.sh`
- stop infra: `local/scripts/stop-infra.sh`
- stop everything: `local/scripts/stop-all.sh`
