# Local Mojaloop Bootstrap

This directory contains a non-container bootstrap for a minimal Mojaloop core stack in this workspace.

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
