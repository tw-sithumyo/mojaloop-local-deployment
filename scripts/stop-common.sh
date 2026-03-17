#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

stop_pid() {
  local label="$1"
  local pid="$2"

  if ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi

  kill "$pid" 2>/dev/null || true

  for _ in $(seq 1 20); do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "$label: stopped pid $pid"
      return 0
    fi
    sleep 1
  done

  kill -9 "$pid" 2>/dev/null || true

  for _ in $(seq 1 5); do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "$label: killed pid $pid"
      return 0
    fi
    sleep 1
  done

  echo "$label: failed to stop pid $pid" >&2
  return 1
}

stop_pid_file() {
  local label="$1"
  local pid_file="$2"

  if [ ! -f "$pid_file" ]; then
    return 1
  fi

  local pid
  pid="$(tr -dc '0-9' < "$pid_file")"
  rm -f "$pid_file"

  if [ -z "$pid" ]; then
    return 1
  fi

  stop_pid "$label" "$pid"
}

stop_pattern() {
  local label="$1"
  local pattern="$2"
  local stopped=1
  local pid

  while read -r pid; do
    [ -n "$pid" ] || continue
    stop_pid "$label" "$pid" || true
    stopped=0
  done < <(pgrep -f "$pattern" || true)

  return "$stopped"
}

stop_port() {
  local label="$1"
  local port="$2"
  local stopped=1
  local pid

  while read -r pid; do
    [ -n "$pid" ] || continue
    stop_pid "$label" "$pid" || true
    stopped=0
  done < <(ss -ltnp "( sport = :$port )" 2>/dev/null | rg -o 'pid=[0-9]+' | cut -d= -f2 | sort -u)

  return "$stopped"
}

stop_named_process() {
  local label="$1"
  local pid_file="${2:-}"
  local port="${3:-}"
  local pattern="${4:-}"
  local stopped=1

  if [ -n "$pid_file" ] && stop_pid_file "$label" "$pid_file"; then
    stopped=0
  fi

  if [ -n "$pattern" ] && stop_pattern "$label" "$pattern"; then
    stopped=0
  fi

  if [ -n "$port" ] && stop_port "$label" "$port"; then
    stopped=0
  fi

  if [ "$stopped" -ne 0 ]; then
    echo "$label: not running"
  fi
}
