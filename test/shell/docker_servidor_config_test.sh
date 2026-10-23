#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/lib/shell/servidor.sh"
SRV=/home/pivotetestcase/servidor
DOCKER_DIR=/tmp/isolated-docker-source

test_ok() (
  DOCKER_SERVIDOR_ROOT="$SRV"
  BASE_DIR="$SRV/current/base"
  DOCKER_WATCH_STATE_DIR="$SRV/state/docker"
  DOCKER_WATCH_REPORTS_DIR="$SRV/state/docker/reports"
  DOCKER_WATCH_EVENTS_LOG="$SRV/logs/docker/events.jsonl"
  docker_servidor_config_guard ""
  [[ "$DOCKER_SERVIDOR_ACTIVE" == true ]]
)
test_reject() (
  local expected="$1"
  shift
  DOCKER_SERVIDOR_ROOT="$SRV"
  BASE_DIR="$SRV/current/base"
  DOCKER_WATCH_STATE_DIR="$SRV/state/docker"
  DOCKER_WATCH_REPORTS_DIR="$SRV/state/docker/reports"
  DOCKER_WATCH_EVENTS_LOG="$SRV/logs/docker/events.jsonl"
  local key val
  for key in "$@"; do
    val="${key#*=}"
    printf -v "${key%%=*}" '%s' "$val"
  done
  if docker_servidor_config_guard "${EXTRA_ENV:-}" 2>"$TMP/error"; then
    echo 'FAIL: unsafe Docker servidor settings accepted' >&2
    exit 1
  fi
  grep -Fq "$expected" "$TMP/error"
)
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
DOCKER_SERVIDOR_ROOT="" docker_servidor_config_guard ""
[[ "$DOCKER_SERVIDOR_ACTIVE" == false ]]
test_ok
test_reject 'Invalid Docker servidor root' DOCKER_SERVIDOR_ROOT=/tmp/servidor
test_reject 'requires managed' BASE_DIR=/opt/base
test_reject 'requires managed' DOCKER_WATCH_STATE_DIR=/var/lib/docker-watch
test_reject 'requires managed' DOCKER_WATCH_REPORTS_DIR=/var/lib/docker-watch/reports
test_reject 'requires managed' DOCKER_WATCH_EVENTS_LOG=/var/log/docker-watch/events.jsonl
test_reject 'forbids --env' EXTRA_ENV=/tmp/unsafe.env
test_reject 'root mismatch' DOCKER_DIR=/home/another/servidor/current/docker
printf 'DOCKER_SERVIDOR_CONFIG_GUARD_PASS\n'
