#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/docker-watch"
USER_NAME="dockwatch"

WATCH_SERVICE="docker-watch.service"
HB_SERVICE="docker-watch-heartbeat.service"
HB_TIMER="docker-watch-heartbeat.timer"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "ERROR: ejecutá como root (sudo)." >&2
  exit 1
fi

systemctl disable --now "${HB_TIMER}" 2>/dev/null || true
systemctl disable --now "${HB_SERVICE}" 2>/dev/null || true
systemctl disable --now "${WATCH_SERVICE}" 2>/dev/null || true

rm -f "/etc/systemd/system/${WATCH_SERVICE}"
rm -f "/etc/systemd/system/${HB_SERVICE}"
rm -f "/etc/systemd/system/${HB_TIMER}"
systemctl daemon-reload

rm -f "/etc/logrotate.d/docker-watch"
rm -rf "${APP_DIR}"
rm -rf "/var/log/docker-watch"
rm -rf "/var/lib/docker-watch"
rm -rf "/run/docker-watch"

if id -u "${USER_NAME}" >/dev/null 2>&1; then
  userdel "${USER_NAME}" 2>/dev/null || true
fi

echo "OK: removido." 
