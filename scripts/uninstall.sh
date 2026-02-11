\
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/docker-watch"
SERVICE_NAME="docker-watch.service"
TIMER_NAME="docker-watch.timer"
USER_NAME="dockerwatch"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "ERROR: ejecutá como root (sudo)." >&2
  exit 1
fi

systemctl disable --now "${TIMER_NAME}" 2>/dev/null || true
systemctl disable --now "${SERVICE_NAME}" 2>/dev/null || true

rm -f "/etc/systemd/system/${SERVICE_NAME}"
rm -f "/etc/systemd/system/${TIMER_NAME}"
systemctl daemon-reload

rm -rf "${APP_DIR}"

if id -u "${USER_NAME}" >/dev/null 2>&1; then
  userdel "${USER_NAME}" 2>/dev/null || true
fi

echo "OK: removido."
