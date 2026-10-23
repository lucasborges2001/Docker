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
grep -Fxq "EnvironmentFile=-$SRV/config/docker/server.env" "$TMP/docker-watch.service"
grep -Fxq "ReadWritePaths=$SRV/state/docker $SRV/logs/docker" "$TMP/docker-watch-telemetry.service"
grep -Fxq "ProtectHome=read-only" "$TMP/docker-watch.service"
grep -Fxq "User=dockwatch" "$TMP/docker-watch.service"
grep -Fxq "Unit=docker-watch-heartbeat.service" "$TMP/docker-watch-heartbeat.timer"
if python3 -B "$RENDER" --root /var/lib/docker-watch --unit docker-watch.service >"$TMP/invalid" 2>/dev/null; then
  echo "FAIL: unsafe root accepted" >&2
  exit 1
fi
if python3 -B "$RENDER" --root "$SRV" --unit unexpected.service >"$TMP/invalid" 2>/dev/null; then
  echo "FAIL: unexpected unit accepted" >&2
  exit 1
fi
echo "DOCKER_SERVIDOR_UNITS_CONTRACT_PASS"
