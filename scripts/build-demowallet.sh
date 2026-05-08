#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

if [ ! -f "$DEMOWALLET_HOME/implementation/pom.xml" ]; then
  echo "Missing DemoWallet Maven project: $DEMOWALLET_HOME/implementation/pom.xml" >&2
  exit 1
fi

(
  cd "$DEMOWALLET_HOME"
  export JAVA_HOME="$DEMOWALLET_JAVA_HOME"
  export PATH="$DEMOWALLET_JAVA_HOME/bin:$MAVEN_HOME/bin:$PATH"
  mvn clean -f implementation install -DskipTests -P local
  mvn clean -f implementation/web_demowallet_api install -DskipTests -P local
)
