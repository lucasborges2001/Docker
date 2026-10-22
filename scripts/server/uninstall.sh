#!/usr/bin/env bash
set -euo pipefail
# Safe by default: --apply plus an explicit confirmation token is required.
# PURGE_DATA=true additionally requires a distinct purge token.
MODE=plan
PURGE_DATA="${PURGE_DATA:-false}"
CONFIRM=""
PURGE_CONFIRM=""
usage() {
  printf 'Usage: %s [--dry-run | --apply --confirm docker-watch] [--purge-data --confirm-purge DELETE_DOCKER_WATCH_DATA]\n' "$0"
}
while (($#)); do
  case "$1" in
    --dry-run) MODE=plan; shift ;;
    --apply) MODE=apply; shift ;;
    --confirm) (($#>=2)) || { usage >&2; exit 2; }; CONFIRM="$2"; shift 2 ;;
    --purge-data) PURGE_DATA=true; shift ;;
    --confirm-purge) (($#>=2)) || { usage >&2; exit 2; }; PURGE_CONFIRM="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
case "$PURGE_DATA" in true|false) ;; *) echo "Invalid PURGE_DATA; expected true or false" >&2; exit 2 ;; esac

INSTALL_DIR=/opt/docker-watch
STATE_DIR=/var/lib/docker-watch
LOG_DIR=/var/log/docker-watch
ENV_DIR=/etc/docker-watch
UNIT_DIR=/etc/systemd/system
UNITS=(
  docker-watch.service
  docker-watch-telemetry.service
  docker-watch-heartbeat.service
  docker-watch-heartbeat.timer
)
die() { printf 'BLOCKED: %s\n' "$1" >&2; exit 2; }
# Literal allowlist, including a separate check that no path component is a symlink.
safe_path() {
  local path="${1:-}" parent
  case "$path" in
    /opt/docker-watch|/var/lib/docker-watch|/var/log/docker-watch|/etc/docker-watch|\
    /etc/systemd/system/docker-watch.service|/etc/systemd/system/docker-watch-telemetry.service|\
    /etc/systemd/system/docker-watch-heartbeat.service|/etc/systemd/system/docker-watch-heartbeat.timer) ;;
    *) die "refusing unexpected path: $path" ;;
  esac
  parent="$path"
  while [[ "$parent" != / ]]; do
    [[ ! -L "$parent" ]] || die "refusing symlink path component: $parent"
    parent="$(dirname -- "$parent")"
  done
}
# Validate the entire intended target set BEFORE stopping units or deleting anything.
for unit in "${UNITS[@]}"; do safe_path "$UNIT_DIR/$unit"; done
safe_path "$INSTALL_DIR"
if [[ "$PURGE_DATA" == true ]]; then
  for path in "$STATE_DIR" "$LOG_DIR" "$ENV_DIR"; do safe_path "$path"; done
fi
printf 'Docker Watch uninstall mode=%s purge_data=%s\n' "$MODE" "$PURGE_DATA"
printf 'Will disable/stop: docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.timer\n'
printf 'Will stop: docker-watch-heartbeat.service\n'
printf 'Will remove: %s/{docker-watch.service,docker-watch-telemetry.service,docker-watch-heartbeat.service,docker-watch-heartbeat.timer} %s\n' "$UNIT_DIR" "$INSTALL_DIR"
if [[ "$PURGE_DATA" == true ]]; then
  printf 'Will purge: %s %s %s\n' "$STATE_DIR" "$LOG_DIR" "$ENV_DIR"
else
  printf 'Will preserve: %s %s %s\n' "$STATE_DIR" "$LOG_DIR" "$ENV_DIR"
fi
if [[ "$MODE" == plan ]]; then
  printf 'DRY_RUN: no changes made. Apply requires --apply --confirm docker-watch.\n'
  exit 0
fi
[[ "$CONFIRM" == docker-watch ]] || die "uninstall requires --confirm docker-watch"
if [[ "$PURGE_DATA" == true ]]; then
  [[ "$PURGE_CONFIRM" == DELETE_DOCKER_WATCH_DATA ]] || die "purge requires --confirm-purge DELETE_DOCKER_WATCH_DATA"
fi
[[ "$EUID" -eq 0 ]] || die "uninstall requires root"
command -v systemctl >/dev/null 2>&1 || die "systemctl missing"
systemctl disable --now docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.timer
systemctl stop docker-watch-heartbeat.service
for unit in "${UNITS[@]}"; do
  rm -f -- "$UNIT_DIR/$unit"
done
systemctl daemon-reload
rm --recursive --force -- "$INSTALL_DIR"
if [[ "$PURGE_DATA" == true ]]; then
  rm --recursive --force -- "$STATE_DIR" "$LOG_DIR" "$ENV_DIR"
fi
printf 'Uninstall complete. Runtime data retained unless purge was explicitly confirmed.\n'
