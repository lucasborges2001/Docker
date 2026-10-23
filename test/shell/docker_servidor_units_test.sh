#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RENDER="$ROOT/scripts/server/render-servidor-units.py"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
SRV=/home/tecnicosfivisa/servidor
for unit in docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.service docker-watch-heartbeat.timer; do
  python3 -B "$RENDER" --root "$SRV" --unit "$unit" >"$TMP/$unit"
done
grep -Fxq "ExecStart=$SRV/current/docker/bin/docker-watch" "$TMP/docker-watch.service"
grep -Fxq "ExecStart=$SRV/current/docker/bin/docker-telemetry --loop" "$TMP/docker-watch-telemetry.service"
grep -Fxq "ExecStart=$SRV/current/docker/bin/docker-heartbeat" "$TMP/docker-watch-heartbeat.service"
grep -Fxq "Environment=BASE_DIR=$SRV/current/base" "$TMP/docker-watch.service"
grep -Fxq "Environment=DOCKER_WATCH_STATE_DIR=$SRV/state/docker" "$TMP/docker-watch.service"
grep -Fxq "Environment=DOCKER_WATCH_EVENTS_LOG=$SRV/logs/docker/events.jsonl" "$TMP/docker-watch.service"
for unit in docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.service; do
  grep -Fxq "Environment=DOCKER_SERVIDOR_ROOT=$SRV" "$TMP/$unit"
  grep -Fxq "EnvironmentFile=$SRV/config/docker/server.env" "$TMP/$unit"
  if grep -Fq "EnvironmentFile=-$SRV/config/docker/server.env" "$TMP/$unit"; then
    echo "FAIL: private Docker server.env must be required in $unit" >&2
    exit 1
  fi
done
grep -Fxq "ReadWritePaths=$SRV/state/docker $SRV/logs/docker" "$TMP/docker-watch-telemetry.service"
grep -Fxq "ProtectHome=read-only" "$TMP/docker-watch.service"
grep -Fxq "User=dockwatch" "$TMP/docker-watch.service"
grep -Fxq "OnCalendar=*-*-* 09:05:00" "$TMP/docker-watch-heartbeat.timer"
if grep -Eq '^On(UnitActiveSec|BootSec)=' "$TMP/docker-watch-heartbeat.timer"; then
  echo "FAIL: servidor heartbeat changed cadence to interval" >&2
  exit 1
fi
grep -Fxq "Unit=docker-watch-heartbeat.service" "$TMP/docker-watch-heartbeat.timer"
if python3 -B "$RENDER" --root /var/lib/docker-watch --unit docker-watch.service >"$TMP/invalid" 2>/dev/null; then
  echo "FAIL: unsafe root accepted" >&2
  exit 1
fi
if python3 -B "$RENDER" --root "$SRV" --unit unexpected.service >"$TMP/invalid" 2>/dev/null; then
  echo "FAIL: unexpected unit accepted" >&2
  exit 1
fi
# Every runtime entrypoint must reject unsafe servidor paths before Base, Docker
# sockets or Telegram are touched. docker-telemetry is not executable in git.
for command in docker-watch docker-telemetry docker-heartbeat; do
  if env -i PATH="$PATH" DOCKER_SERVIDOR_ROOT="$SRV" BASE_DIR=/opt/base DOCKER_WATCH_STATE_DIR="$SRV/state/docker" DOCKER_WATCH_REPORTS_DIR="$SRV/state/docker/reports" DOCKER_WATCH_EVENTS_LOG="$SRV/logs/docker/events.jsonl" bash "$ROOT/bin/$command" >"$TMP/rejected.stdout" 2>"$TMP/rejected.stderr"; then
    echo "FAIL: $command accepted unpinned Base in servidor" >&2
    exit 1
  fi
  grep -Fq "Docker servidor requires managed" "$TMP/rejected.stderr"
  if env -i PATH="$PATH" DOCKER_SERVIDOR_ROOT="$SRV" BASE_DIR="$SRV/current/base" DOCKER_WATCH_STATE_DIR=/var/lib/docker-watch DOCKER_WATCH_REPORTS_DIR="$SRV/state/docker/reports" DOCKER_WATCH_EVENTS_LOG="$SRV/logs/docker/events.jsonl" bash "$ROOT/bin/$command" >"$TMP/rejected.stdout" 2>"$TMP/rejected.stderr"; then
    echo "FAIL: $command accepted external state" >&2
    exit 1
  fi
  grep -Fq "Docker servidor requires managed" "$TMP/rejected.stderr"
done
echo "DOCKER_SERVIDOR_UNITS_CONTRACT_PASS"
