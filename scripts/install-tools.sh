#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

TOOLS_DIR="$ROOT_DIR/tools"
mkdir -p "$TOOLS_DIR"

NODE_VERSION="v22.22.0"
NODE_ARCHIVE="node-${NODE_VERSION}-linux-x64.tar.xz"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/${NODE_ARCHIVE}"
NODE_TARGET_DIR="$TOOLS_DIR/node-${NODE_VERSION}-linux-x64"

JAVA_VERSION="21.0.10_7"
JAVA_ARCHIVE="OpenJDK21U-jre_x64_linux_hotspot_${JAVA_VERSION}.tar.gz"
JAVA_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.10%2B7/${JAVA_ARCHIVE}"
JAVA_TARGET_DIR="$TOOLS_DIR/jdk-21.0.10+7-jre"

JDK11_VERSION="11.0.27_6"
JDK11_ARCHIVE="OpenJDK11U-jdk_x64_linux_hotspot_${JDK11_VERSION}.tar.gz"
JDK11_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.27%2B6/${JDK11_ARCHIVE}"
JDK11_TARGET_DIR="$TOOLS_DIR/jdk-11.0.27+6"

MAVEN_VERSION="3.9.10"
MAVEN_ARCHIVE="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_ARCHIVE}"
MAVEN_TARGET_DIR="$TOOLS_DIR/apache-maven-${MAVEN_VERSION}"

KAFKA_VERSION="3.9.1"
KAFKA_ARCHIVE="kafka_2.13-${KAFKA_VERSION}.tgz"
KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_ARCHIVE}"
KAFKA_TARGET_DIR="$TOOLS_DIR/kafka_2.13-${KAFKA_VERSION}"

NATS_VERSION="2.12.5"
NATS_ARCHIVE="nats-server-v${NATS_VERSION}-linux-amd64.tar.gz"
NATS_URL="https://github.com/nats-io/nats-server/releases/download/v${NATS_VERSION}/${NATS_ARCHIVE}"
NATS_TARGET_DIR="$TOOLS_DIR/nats-server-v${NATS_VERSION}-linux-amd64"

download_to() {
  local url="$1"
  local archive_path="$2"

  if [ -f "$archive_path" ]; then
    return
  fi

  curl -fL "$url" -o "$archive_path"
}

install_tar_gz() {
  local target_dir="$1"
  local archive_path="$2"

  if [ -d "$target_dir" ]; then
    return
  fi

  tar -xzf "$archive_path" -C "$TOOLS_DIR"
}

install_tar_xz() {
  local target_dir="$1"
  local archive_path="$2"

  if [ -d "$target_dir" ]; then
    return
  fi

  tar -xJf "$archive_path" -C "$TOOLS_DIR"
}

download_to "$NODE_URL" "$TOOLS_DIR/$NODE_ARCHIVE"
install_tar_xz "$NODE_TARGET_DIR" "$TOOLS_DIR/$NODE_ARCHIVE"

download_to "$JAVA_URL" "$TOOLS_DIR/$JAVA_ARCHIVE"
install_tar_gz "$JAVA_TARGET_DIR" "$TOOLS_DIR/$JAVA_ARCHIVE"

download_to "$JDK11_URL" "$TOOLS_DIR/$JDK11_ARCHIVE"
install_tar_gz "$JDK11_TARGET_DIR" "$TOOLS_DIR/$JDK11_ARCHIVE"

download_to "$MAVEN_URL" "$TOOLS_DIR/$MAVEN_ARCHIVE"
install_tar_gz "$MAVEN_TARGET_DIR" "$TOOLS_DIR/$MAVEN_ARCHIVE"

download_to "$KAFKA_URL" "$TOOLS_DIR/$KAFKA_ARCHIVE"
install_tar_gz "$KAFKA_TARGET_DIR" "$TOOLS_DIR/$KAFKA_ARCHIVE"

download_to "$NATS_URL" "$TOOLS_DIR/$NATS_ARCHIVE"
install_tar_gz "$NATS_TARGET_DIR" "$TOOLS_DIR/$NATS_ARCHIVE"

echo "Installed workspace tools under $TOOLS_DIR"
echo "Node:  $NODE_TARGET_DIR"
echo "Java:  $JAVA_TARGET_DIR"
echo "JDK11: $JDK11_TARGET_DIR"
echo "Maven: $MAVEN_TARGET_DIR"
echo "Kafka: $KAFKA_TARGET_DIR"
echo "NATS:  $NATS_TARGET_DIR"
