#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

SDK_REPO="$ROOT_DIR/sdk-scheme-adapter"
CC_REPO="$ROOT_DIR/ml-thitsawallet-cc"
CC_TARGET_DIR="$CC_REPO/implementation/web_fsp_connector_api/target"
CC_JAR="$CC_TARGET_DIR/fsp_connector_api.jar"
CC_LIB_DIR="$CC_TARGET_DIR/lib"
CC_BUILD_STAMP="$CC_TARGET_DIR/.codex-cc-build.stamp"
CC_MAIN_CLASS="com.thitsaworks.mojaloop.coreconnector.fsp.connector.FspConnectorApiApplication"
MAVEN_HOME="$ROOT_DIR/tools/apache-maven-3.9.10"

wait_http() {
  local label="$1"
  local port="$2"
  local path="$3"

  for _ in $(seq 1 180); do
    if curl -fsS "http://127.0.0.1:${port}${path}" >/dev/null 2>&1; then
      echo "${label}: ready on ${port}${path}"
      return 0
    fi
    sleep 1
  done

  echo "${label}: did not become ready on ${port}${path}" >&2
  return 1
}

wait_port() {
  local label="$1"
  local port="$2"

  for _ in $(seq 1 120); do
    if ss -ltn | rg -q "[:.]${port}\\b"; then
      echo "${label}: listening on ${port}"
      return 0
    fi
    sleep 1
  done

  echo "${label}: did not start listening on ${port}" >&2
  return 1
}

require_listening_port() {
  local label="$1"
  local port="$2"

  if ! ss -ltn | rg -q "[:.]${port}\\b"; then
    echo "${label} is not listening on ${port}. Start the core stack first." >&2
    return 1
  fi
}

read_pid() {
  local pid_file="$1"
  if [ ! -f "$pid_file" ]; then
    return 1
  fi
  tr -dc '0-9' < "$pid_file"
}

pid_running() {
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

resolve_jdk_home() {
  if [ -x "$ROOT_DIR/tools/jdk-11.0.27+6/bin/javac" ]; then
    printf '%s\n' "$ROOT_DIR/tools/jdk-11.0.27+6"
    return 0
  fi

  if [ -x "$ROOT_DIR/tools/jdk-21.0.10+7/bin/javac" ]; then
    printf '%s\n' "$ROOT_DIR/tools/jdk-21.0.10+7"
    return 0
  fi

  if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/javac" ]; then
    printf '%s\n' "$JAVA_HOME"
    return 0
  fi

  local javac_bin
  javac_bin="$(command -v javac || true)"
  if [ -n "$javac_bin" ]; then
    dirname "$(dirname "$(readlink -f "$javac_bin")")"
    return 0
  fi

  echo "No compatible JDK found. Install workspace tools with local/scripts/install-tools.sh." >&2
  return 1
}

resolve_maven_cmd() {
  if [ -x "$MAVEN_HOME/bin/mvn" ]; then
    printf '%s\n' "$MAVEN_HOME/bin/mvn"
    return 0
  fi

  local mvn_bin
  mvn_bin="$(command -v mvn || true)"
  if [ -n "$mvn_bin" ]; then
    printf '%s\n' "$mvn_bin"
    return 0
  fi

  echo "Maven is not available. Install it or run local/scripts/install-tools.sh." >&2
  return 1
}

ensure_sdk_dependencies() {
  if [ -d "$SDK_REPO/node_modules" ]; then
    return 0
  fi

  (
    cd "$SDK_REPO"
    corepack yarn install --immutable
  )
}

cc_needs_build() {
  if [ ! -f "$CC_JAR" ] || [ ! -d "$CC_LIB_DIR" ] || [ ! -f "$CC_BUILD_STAMP" ]; then
    return 0
  fi

  if find "$CC_REPO/implementation" \
    -type f \
    \( -name '*.java' -o -name '*.xml' -o -name '*.properties' \) \
    ! -path '*/target/*' \
    ! -path "$CC_REPO/implementation/mod_fspiop_interface/src/main/java/*" \
    ! -path "$CC_REPO/implementation/mod_fspiop_interface/.openapi-generator/*" \
    -newer "$CC_BUILD_STAMP" \
    -print -quit | grep -q .; then
    return 0
  fi

  return 1
}

ensure_cc_built() {
  local jdk_home="$1"
  local mvn_cmd="$2"

  if ! cc_needs_build; then
    return 0
  fi

  local mvn_dir
  mvn_dir="$(dirname "$mvn_cmd")"

  (
    cd "$CC_REPO"
    env \
      JAVA_HOME="$jdk_home" \
      PATH="$jdk_home/bin:$mvn_dir:$PATH" \
      "$mvn_cmd" -f implementation/mod_fspiop_interface -P local clean install
    env \
      JAVA_HOME="$jdk_home" \
      PATH="$jdk_home/bin:$mvn_dir:$PATH" \
      "$mvn_cmd" -f implementation -P local install -DskipTests
    env \
      JAVA_HOME="$jdk_home" \
      PATH="$jdk_home/bin:$mvn_dir:$PATH" \
      "$mvn_cmd" -f implementation/web_fsp_connector_api -P local install -DskipTests
  )

  touch "$CC_BUILD_STAMP"
}

start_shell_process() {
  local name="$1"
  local workdir="$2"
  local port="$3"
  local script="$4"
  local pid_file="$RUN_DIR/${name}.pid"
  local log_file="$LOG_DIR/${name}.log"
  local pid

  pid="$(read_pid "$pid_file" || true)"
  if [ -n "$pid" ] && pid_running "$pid"; then
    echo "${name}: already running with pid ${pid}"
    return 0
  fi

  if [ -n "$port" ] && ss -ltn | rg -q "[:.]${port}\\b"; then
    echo "${name}: port ${port} is already in use" >&2
    return 1
  fi

  rm -f "$pid_file"
  : > "$log_file"

  local workdir_q pid_file_q
  printf -v workdir_q '%q' "$workdir"
  printf -v pid_file_q '%q' "$pid_file"

  setsid -f bash -lc "cd ${workdir_q}; echo \$\$ > ${pid_file_q}; ${script}" >"$log_file" 2>&1 < /dev/null
}
