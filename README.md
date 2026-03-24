# Local Mojaloop Bootstrap

This repository is not standalone.

`local/env.sh` sets `ROOT_DIR` to the parent directory of this repository, so the bootstrap expects a shared workspace layout with this repo and the service repos cloned side-by-side.

All commands below are run from `ROOT_DIR`, which is the parent directory of `local/`, not from inside `local/` itself.

Tool prerequisites:

- Node.js and `npm`
  - expected under `tools/node-v22.22.0-linux-x64`
- Java
  - expected under `tools/jdk-21.0.10+7`
  - `local/env.sh` falls back to `tools/jdk-21.0.10+7-jre` if only the JRE exists
- CC build JDK
  - expected under `tools/jdk-11.0.27+6`
  - `ml-thitsawallet-cc` follows its own Dockerfile and builds cleanly on JDK 11
- Maven
  - expected under `tools/apache-maven-3.9.10`
- Kafka binaries
  - expected under `tools/kafka_2.13-3.9.1`
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
- Java
- JDK 11 for `ml-thitsawallet-cc`
- Kafka
- NATS server
- Maven

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
  sdk-scheme-adapter/         # optional, only needed for wallet DFSP flows
  ml-thitsawallet-cc/         # optional, only needed for wallet DFSP flows
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

- `sdk-scheme-adapter`
- `ml-thitsawallet-cc`

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
git clone https://github.com/mojaloop/sdk-scheme-adapter.git sdk-scheme-adapter
git clone https://github.com/tw-sithumyo/ml-thitsawallet-cc.git ml-thitsawallet-cc
```

This directory contains a non-container bootstrap for a minimal Mojaloop core stack in that workspace.

Order:

1. `source local/env.sh`
2. `local/scripts/start-infra.sh`
3. `local/scripts/npm-ci-all.sh`
4. `local/scripts/migrate-all.sh`
5. `local/scripts/start-services.sh`

Optional `wallet1` DFSP bootstrap with `sdk-scheme-adapter` + `ml-thitsawallet-cc`:

6. `local/scripts/setup-wallet1.sh`
7. `local/scripts/test-wallet1-flow.sh`

Optional `wallet2` DFSP bootstrap and inter-DFSP test:

8. `local/scripts/setup-wallet2.sh`
9. `local/scripts/test-wallet1-wallet2-flow.sh`

Stop commands:

- stop the local web UI: `local/scripts/stop-ui.sh`
- stop core services: `local/scripts/stop-services.sh`
- stop wallet-side CC + SDK services: `local/scripts/stop-wallet-services.sh`
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

The wallet flow in this branch is local-process only:

- it does not use Docker or Docker Compose
- it uses `sdk-scheme-adapter` as the hub-facing DFSP adapter
- it uses `ml-thitsawallet-cc` as the wallet-facing core connector
- it runs a tiny local mock backend per wallet for quote and transfer crediting
- it onboards `wallet1` and `wallet2` into Central Ledger with callback endpoints that point to the local `sdk-scheme-adapter` inbound ports
- it verifies a real `wallet1 -> wallet2` 3-step CC flow using `sendmoney -> acceptParty -> acceptQuote -> transfer`

Current limitation:

- the current `wallet1 -> wallet2` flow is a directed payee lookup through the hub because the payer request includes `to.fspId=wallet2`
- it does not register ALS oracle data for true identifier-only oracle lookup yet
