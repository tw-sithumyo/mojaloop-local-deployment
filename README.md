# Local Mojaloop Bootstrap

This repository is not standalone.

`local/env.sh` sets `ROOT_DIR` to the parent directory of this repository, so the bootstrap expects a shared workspace layout with this repo and the service repos cloned side-by-side.

All commands below are run from `ROOT_DIR`, which is the parent directory of `local/`, not from inside `local/` itself.

Tool prerequisites:

- Node.js and `npm`
  - expected under `tools/node-v22.22.0-linux-x64`
- Java runtime
  - expected under `tools/jdk-21.0.10+7-jre`
- Java JDK and Maven
  - expected under `tools/jdk-11.0.27+6`, `tools/jdk-21.0.10+7`, and `tools/apache-maven-3.9.10`
  - JDK 11 is used to build `Mojaloop-DemoWallet` and `ml-thitsawallet-cc`
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
- JDK 11
- Maven
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
  pivotal-new/                   # optional, only needed for wallet DFSP flows
  pivotal-connector-nestjs/      # optional, wallet connector process for pivotal-new
  Mojaloop-DemoWallet/           # optional, local wallet backend for wallet1/wallet2
  sdk-scheme-adapter/             # optional, alternative core-connector wallet stack
  ml-thitsawallet-cc/             # optional, alternative core-connector wallet stack
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

- `pivotal-new`
- `pivotal-connector-nestjs`
- `Mojaloop-DemoWallet`

Additional sibling repos for the alternative core-connector wallet flow:

- `sdk-scheme-adapter`
- `ml-thitsawallet-cc`

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
git clone https://github.com/ThitsaX/pivotal.git pivotal-new
git clone https://github.com/ThitsaX/pivotal-connector-nestjs.git pivotal-connector-nestjs
git clone https://github.com/ThitsaX/Mojaloop-DemoWallet.git Mojaloop-DemoWallet
git clone https://github.com/mojaloop/sdk-scheme-adapter.git sdk-scheme-adapter
git clone https://github.com/tw-sithumyo/ml-thitsawallet-cc.git ml-thitsawallet-cc
git clone https://github.com/mojaloop/reporting-aggregator-svc.git reporting-aggregator-svc
```

This directory contains a non-container bootstrap for a minimal Mojaloop core stack in that workspace.

Interactive start for the local stack:

```bash
local/scripts/start-all.sh
```

Start the normal full stack without the checklist:

```bash
local/scripts/start-all.sh --all
```

This starts infra, Mojaloop core services, wallet1, wallet2, Pivotal portal API/UI, and the local monitor UI. Optional stacks are off by default:

```bash
START_ALL_REPORTING=1 START_ALL_TAZAMA=1 START_ALL_PPA=1 local/scripts/start-all.sh
```

Generate randomized successful transfers for testing the Pivotal dashboard:

```bash
local/scripts/generate-dashboard-transfers.sh
```

The generator defaults to 20 `wallet1 -> wallet2` transfers, amounts from 5 to 75, and a mix of
locally registered use cases. It restarts only app-auditor after the batch so the dashboard rollup
is immediately refreshed. Override its inputs when needed:

```bash
DASHBOARD_TRANSFER_COUNT=30 \
DASHBOARD_TRANSFER_MIN_AMOUNT=10 \
DASHBOARD_TRANSFER_MAX_AMOUNT=250 \
DASHBOARD_TRANSFER_SUB_SCENARIOS=PERSON_TO_PERSON,PERSON_TO_BUSINESS \
local/scripts/generate-dashboard-transfers.sh
```

Useful flags:

- `START_ALL_NPM_CI=auto|always|skip`
- `START_ALL_SELECT=0` starts the normal full stack without the checklist
- `START_ALL_MIGRATE=0` skips migrations
- `START_ALL_UI=0` skips the local monitor UI
- `START_ALL_COMPONENTS=infra,migrations,core,wallet1,wallet2` runs an explicit subset without the checklist

Order:

1. `source local/env.sh`
2. `local/scripts/start-infra.sh`
3. `local/scripts/npm-ci-all.sh`
4. `local/scripts/migrate-all.sh`
5. `local/scripts/start-mojaloop-core-services.sh`

Optional `wallet1` DFSP bootstrap with `pivotal-new`, `pivotal-connector-nestjs`, and `Mojaloop-DemoWallet`:

6. `local/scripts/setup-wallet1.sh`
7. `local/scripts/test-wallet1-flow.sh`

Optional `wallet2` DFSP bootstrap and inter-DFSP test:

8. `local/scripts/setup-wallet2.sh`
9. `local/scripts/test-wallet1-wallet2-flow.sh`

## Notification Timeout Repro

The prod timeout issue can be reproduced locally by delaying the payee `POST /transfers`
callback after Central Ledger has already produced the prepare notification.

Required services:

- core services from `local/scripts/start-mojaloop-core-services.sh`
- wallet services from `local/scripts/setup-wallet1.sh` and `local/scripts/setup-wallet2.sh`

Run:

```bash
local/scripts/test-notification-timeout-repro.sh
```

What it does:

- starts a local delay proxy on `127.0.0.1:3299`
- temporarily points wallet2 `FSPIOP_CALLBACK_URL_TRANSFER_POST` to that proxy
- sends a `wallet1 -> wallet2` transfer with a short transfer expiration
- delays payee `POST /transfers` long enough for the Hub timeout handler to expire the transfer
- restores wallet2 `FSPIOP_CALLBACK_URL_TRANSFER_POST` when the script exits

Expected result:

- payer-side transfer fails instead of committing
- `central-ledger-handlers.log` shows `Transfer expired`
- late fulfil from wallet2 is rejected with `non-RESERVED transfer state`

Useful tuning:

```bash
REPRO_TRANSFER_EXPIRY_SECONDS=5 \
REPRO_PAYEE_DELAY_MS=17000 \
REPRO_POST_TRANSFER_WAIT_SECONDS=6 \
local/scripts/test-notification-timeout-repro.sh
```

The delay proxy can also be controlled directly:

```bash
DELAY_PROXY_TARGET=http://127.0.0.1:3201 DELAY_PROXY_DELAY_MS=17000 local/scripts/start-delay-proxy.sh
local/scripts/stop-delay-proxy.sh
```

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

The wallet flow is intentionally minimal for now:

- it uses `pivotal-new` as the DFSP app layer
- it runs Pivotal app-auditor so the `pivotal` schema is migrated and audit events are consumed
- it runs Pivotal portal API on `127.0.0.1:3202`
- it runs Pivotal portal UI on `127.0.0.1:4173`
- it runs `pivotal-connector-nestjs` as the wallet connector process
- it runs `Mojaloop-DemoWallet` as the local wallet backend
- it initializes the local Pivotal MySQL schema and `pivotal/password` user
- it initializes DemoWallet MySQL schemas from `Mojaloop-DemoWallet/init-multi.sql`
- wallet1 backend listens on `127.0.0.1:8081` with schema `wallet1`
- wallet2 backend listens on `127.0.0.1:8082` with schema `wallet2`
- it starts a local `nats-server` with JetStream
- it creates the required `PIVOTAL_FSPIOP` and `PIVOTAL_AUDIT` streams
- it onboards `wallet1` into Central Ledger
- it enables on-us transfers in local `central-ledger` so a single-DFSP self-flow can complete
- it verifies flows using Pivotal's 3-step `/secured/sendmoney` route

Current limitation:

- `pivotal` outbound does not expose the older separate local `/lookup`, `/quote`, and `/transfer` test routes; the local tests use `POST /secured/sendmoney`, `PUT /secured/sendmoney/{id}` with `acceptParty`, then `PUT /secured/sendmoney/{id}` with `acceptQuote`

## Core-Connector Wallet Alternative

Pivotal remains the default wallet stack. The repository also supports an alternative
local-process flow using `sdk-scheme-adapter`, `ml-thitsawallet-cc`, and a small mock
wallet backend. The two wallet stacks share ports 3200 and 3201, so stop the active
wallet stack before switching.

Start, onboard, and test the core-connector alternative:

```bash
local/scripts/stop-wallet-services.sh
WALLET_STACK=core local/scripts/setup-wallet1.sh
WALLET_STACK=core local/scripts/setup-wallet2.sh
WALLET_STACK=core local/scripts/test-wallet1-wallet2-flow.sh
```

The core-connector flow:

- runs locally without Docker or Docker Compose
- uses `sdk-scheme-adapter` as the hub-facing DFSP adapter
- uses `ml-thitsawallet-cc` as the wallet-facing connector
- starts one mock backend for each wallet
- onboards both wallets with their SDK inbound callback endpoints
- verifies the `sendmoney -> acceptParty -> acceptQuote -> transfer` flow

The current payer request includes `to.fspId=wallet2`; identifier-only ALS oracle
lookup is not configured yet.

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
- stop Pivotal portal API/UI: `local/scripts/stop-pivotal-portal-services.sh`
- stop either wallet stack: `local/scripts/stop-wallet-services.sh`
- stop core services: `local/scripts/stop-services.sh`
- stop infra: `local/scripts/stop-infra.sh`
- stop everything: `local/scripts/stop-all.sh`
