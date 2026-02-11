\
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/docker-watch"
SERVICE_NAME="docker-watch.service"
TIMER_NAME="docker-watch.timer"
USER_NAME="dockerwatch"
GROUP_NAME="dockerwatch"

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

echo "[1/7] Creando usuario dedicado (${USER_NAME}) si no existe..."
if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
  useradd --system --home "${APP_DIR}" --shell /usr/sbin/nologin --user-group "${USER_NAME}"
fi

echo "[2/7] Asegurando membresía al grupo docker..."
if getent group docker >/dev/null 2>&1; then
  usermod -aG docker "${USER_NAME}"
else
  echo "WARN: no existe grupo docker; ¿Docker instalado correctamente?"
fi

echo "[3/7] Creando directorio ${APP_DIR}..."
install -d -m 0750 -o "${USER_NAME}" -g "${GROUP_NAME}" "${APP_DIR}"

echo "[4/7] Instalando script..."
install -m 0750 -o "${USER_NAME}" -g "${GROUP_NAME}" "./docker-watch.sh" "${APP_DIR}/docker-watch.sh"

echo "[5/7] Instalando .env..."
if [[ -f "${APP_DIR}/.env" ]]; then
  echo " - ${APP_DIR}/.env ya existe, no lo toco."
else
  install -m 0640 -o "${USER_NAME}" -g "${GROUP_NAME}" "./.env.example" "${APP_DIR}/.env"
  echo " - Copié .env.example -> ${APP_DIR}/.env (EDITALO con tu BOT_TOKEN y CHAT_ID)."
fi

echo "[6/7] Instalando unit + timer..."
install -m 0644 "./systemd/${SERVICE_NAME}" "/etc/systemd/system/${SERVICE_NAME}"
install -m 0644 "./systemd/${TIMER_NAME}"   "/etc/systemd/system/${TIMER_NAME}"

echo "[7/7] Activando timer..."
systemctl daemon-reload
systemctl enable --now "${TIMER_NAME}"

echo ""
echo "OK. Próximos pasos:"
echo "  1) Editá ${APP_DIR}/.env"
echo "  2) Forzar ejecución: sudo systemctl start ${SERVICE_NAME}"
echo "  3) Logs: journalctl -u ${SERVICE_NAME} -b --no-pager"
echo "  4) Estado timer: systemctl status ${TIMER_NAME} --no-pager"
