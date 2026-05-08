#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

ENV_FILE="$CONF_DIR/wallet2-pivotal.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing wallet2 env file: $ENV_FILE" >&2
  exit 1
fi

if [ ! -d "$PIVOTAL_HOME/node_modules" ]; then
  echo "Missing pivotal/node_modules. Run local/scripts/npm-ci-pivotal.sh first." >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

PIVOTAL_HOME="$PIVOTAL_HOME" node - <<'NODE'
const { connect } = require(`${process.env.PIVOTAL_HOME}/node_modules/nats`);

const NO_STREAM_MATCHES_SUBJECT = 'no stream matches subject';
const STREAM_ALREADY_EXISTS = 'stream name already in use';

const isExpectedError = (error, text) => {
  const message = String(error && error.message || error).toLowerCase();
  return message.includes(text);
};

const streamDefinitions = [
  {
    lookupSubject: 'fspiop.wallet2.bootstrap',
    name: process.env.PIVOTAL_FSPIOP_STREAM_NAME || 'PIVOTAL_FSPIOP',
    subjects: ['fspiop.>'],
  },
  {
    lookupSubject: 'audit.wallet2.bootstrap',
    name: process.env.PIVOTAL_AUDIT_STREAM_NAME || 'PIVOTAL_AUDIT',
    subjects: ['audit.>'],
  },
];

(async () => {
  const nc = await connect({ servers: process.env.NATS_URL || 'nats://127.0.0.1:4222' });
  const jsm = await nc.jetstreamManager();

  for (const definition of streamDefinitions) {
    try {
      const existing = await jsm.streams.find(definition.lookupSubject);
      console.log(`${definition.lookupSubject} -> ${existing}`);
      continue;
    } catch (error) {
      if (!isExpectedError(error, NO_STREAM_MATCHES_SUBJECT)) {
        throw error;
      }
    }

    try {
      await jsm.streams.add({
        name: definition.name,
        subjects: definition.subjects,
      });
      console.log(`created ${definition.name}`);
    } catch (error) {
      if (!isExpectedError(error, STREAM_ALREADY_EXISTS)) {
        throw error;
      }
      console.log(`${definition.name} already exists`);
    }
  }

  await nc.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
