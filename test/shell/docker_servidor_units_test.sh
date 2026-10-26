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
# Regression guard: exact directives and section placement for the physical cutover.
assert_exact_once() {
  local file="$1" line="$2" count
  count="$(grep -Fxc -- "$line" "$file" || true)"
  if [[ "$count" != 1 ]]; then
    echo "FAIL: expected exactly once in $file: $line (found $count)" >&2
    exit 1
  fi
}
for unit in docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.service; do
  file="$TMP/$unit"
  for line in \
    'User=dockwatch' 'Group=dockwatch' \
    "Environment=BASE_DIR=$SRV/current/base" "Environment=DOCKER_SERVIDOR_ROOT=$SRV" \
    "Environment=DOCKER_WATCH_STATE_DIR=$SRV/state/docker" \
    "Environment=DOCKER_WATCH_REPORTS_DIR=$SRV/state/docker/reports" \
    "Environment=DOCKER_WATCH_EVENTS_LOG=$SRV/logs/docker/events.jsonl" \
    "EnvironmentFile=$SRV/config/docker/server.env" \
    'NoNewPrivileges=true' 'PrivateTmp=true' 'ProtectSystem=strict' \
    'ProtectHome=read-only' "ReadWritePaths=$SRV/state/docker $SRV/logs/docker" \
    'UMask=0027'; do
    assert_exact_once "$file" "$line"
  done
  if grep -Eq '^(User=root|EnvironmentFile=-|ExecStart=/opt/|.*=/var/lib/docker-watch)' "$file"; then
    echo "FAIL: unsafe legacy/root policy in $unit" >&2; exit 1
  fi
done
for unit in docker-watch.service docker-watch-heartbeat.service; do
  file="$TMP/$unit"
  for line in \
    'SupplementaryGroups=docker' 'ProtectKernelTunables=true' \
    'ProtectKernelModules=true' 'ProtectControlGroups=true' 'LockPersonality=true' \
    'MemoryDenyWriteExecute=true' 'RestrictSUIDSGID=true' \
    'RestrictRealtime=true' 'RestrictNamespaces=true' \
    'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6'; do
    assert_exact_once "$file" "$line"
  done
done
assert_exact_once "$TMP/docker-watch.service" 'Restart=on-failure'
assert_exact_once "$TMP/docker-watch.service" 'RestartSec=5s'
assert_exact_once "$TMP/docker-watch.service" 'StartLimitIntervalSec=60'
assert_exact_once "$TMP/docker-watch.service" 'StartLimitBurst=5'
if grep -Fxq 'Restart=always' "$TMP/docker-watch.service"; then
  echo 'FAIL: watcher cannot use Restart=always' >&2; exit 1
fi
awk '/^\[/{section=$0} /^StartLimit(IntervalSec|Burst)=/{if (section != "[Unit]") exit 1}' "$TMP/docker-watch.service"
assert_exact_once "$TMP/docker-watch-telemetry.service" 'Restart=always'
assert_exact_once "$TMP/docker-watch-heartbeat.service" 'Type=oneshot'
if grep -Eq '^Restart=' "$TMP/docker-watch-heartbeat.service"; then
  echo 'FAIL: heartbeat oneshot should not restart' >&2; exit 1
fi
assert_exact_once "$TMP/docker-watch-heartbeat.timer" 'Persistent=true'
assert_exact_once "$TMP/docker-watch-heartbeat.timer" 'Unit=docker-watch-heartbeat.service'
if command -v systemd-analyze >/dev/null 2>&1; then
  mkdir -p "$TMP/verified"
  for unit in docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.service; do
    # Validate the same directives without requiring the physical servidor binaries.
    sed -E 's|^ExecStart=.*|ExecStart=/bin/true|' "$TMP/$unit" > "$TMP/verified/$unit"
  done
  cp "$TMP/docker-watch-heartbeat.timer" "$TMP/verified/docker-watch-heartbeat.timer"
  systemd-analyze verify "$TMP/verified/"*.service "$TMP/verified/"*.timer
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
