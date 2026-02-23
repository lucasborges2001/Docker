#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/docker-watch"
USER_NAME="dockwatch"
GROUP_NAME="dockwatch"

WATCH_SERVICE="docker-watch.service"
HB_SERVICE="docker-watch-heartbeat.service"
HB_TIMER="docker-watch-heartbeat.timer"

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: ejecutá como root (sudo)." >&2
    exit 1
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: falta comando: $1" >&2; exit 1; }
}

need_root
need_cmd systemctl
need_cmd install
need_cmd docker
need_cmd useradd
need_cmd usermod

echo "[1/10] Creando usuario dedicado (${USER_NAME}) si no existe..."
if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
  useradd -r -s /usr/sbin/nologin -d "${APP_DIR}" "${USER_NAME}"
fi

echo "[2/10] Asegurando membresía al grupo docker..."
if getent group docker >/dev/null 2>&1; then
  usermod -aG docker "${USER_NAME}"
else
  echo "WARN: no existe grupo docker; ¿Docker instalado correctamente?" >&2
fi

echo "[3/10] Creando directorios..."
install -d -m 0750 -o "${USER_NAME}" -g "${GROUP_NAME}" "${APP_DIR}"
install -d -m 0750 -o "${USER_NAME}" -g "${GROUP_NAME}" "${APP_DIR}/lib"

echo "[4/10] Instalando scripts..."
install -m 0750 -o "${USER_NAME}" -g "${GROUP_NAME}" "./docker-watch.sh" "${APP_DIR}/docker-watch.sh"
install -m 0750 -o "${USER_NAME}" -g "${GROUP_NAME}" "./heartbeat.sh"   "${APP_DIR}/heartbeat.sh"

echo "[5/10] Instalando lib (estilo Boot)..."
install -m 0640 -o "${USER_NAME}" -g "${GROUP_NAME}" "./lib/telegram.sh" "${APP_DIR}/lib/telegram.sh"
install -m 0640 -o "${USER_NAME}" -g "${GROUP_NAME}" "./lib/render.sh"   "${APP_DIR}/lib/render.sh"

echo "[6/10] Instalando .env..."
if [[ -f "${APP_DIR}/.env" ]]; then
  echo " - ${APP_DIR}/.env ya existe, no lo toco."
else
  install -m 0640 -o "${USER_NAME}" -g "${GROUP_NAME}" "./.env.example" "${APP_DIR}/.env"
  echo " - Copié .env.example -> ${APP_DIR}/.env (EDITALO con tu BOT_TOKEN y CHAT_ID)."
fi

echo "[7/10] Instalando units systemd..."
install -m 0644 "./systemd/${WATCH_SERVICE}" "/etc/systemd/system/${WATCH_SERVICE}"
install -m 0644 "./systemd/${HB_SERVICE}"    "/etc/systemd/system/${HB_SERVICE}"
install -m 0644 "./systemd/${HB_TIMER}"      "/etc/systemd/system/${HB_TIMER}"

echo "[8/10] Preparando state/logs + logrotate..."
install -d -m 0750 -o "${USER_NAME}" -g "${GROUP_NAME}" "/var/lib/docker-watch"
install -d -m 0750 -o "${USER_NAME}" -g "${GROUP_NAME}" "/var/log/docker-watch"
install -m 0644 "./scripts/docker-watch.logrotate" "/etc/logrotate.d/docker-watch"

echo "[9/10] Activando watcher + heartbeat timer..."
systemctl daemon-reload
systemctl enable --now "${WATCH_SERVICE}"
systemctl enable --now "${HB_TIMER}"

echo "[10/10] Estado:"
systemctl --no-pager --full status "${WATCH_SERVICE}" || true
systemctl --no-pager --full status "${HB_TIMER}" || true

echo ""
echo "OK. Próximos pasos:"
echo "  1) Editá ${APP_DIR}/.env"
echo "  2) Probar heartbeat ahora: sudo systemctl start ${HB_SERVICE}"
echo "  3) Logs watcher: journalctl -u ${WATCH_SERVICE} -b --no-pager"
