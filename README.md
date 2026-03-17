# Local Mojaloop Bootstrap

This directory contains a non-container bootstrap for a minimal Mojaloop core stack in this workspace.

Order:

1. `source local/env.sh`
2. `local/scripts/start-infra.sh`
3. `local/scripts/npm-ci-all.sh`
4. `local/scripts/migrate-all.sh`
5. `local/scripts/start-services.sh`
