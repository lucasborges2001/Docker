#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# DOCKER HEARTBEAT
# -----------------------------------------------------------------------------
# Verificación periódica del estado del entorno Docker.
#
# Detecta:
#   🔴 Docker daemon caído
#   🔴 docker-watch.service caído
#   🔴 Contenedor esperado no running
#   🟠 Contenedor unhealthy
#
# No envía reportes normales.
# Solo alerta cuando hay problema real.
#
# Recomendado: ejecutar cada 5 o 10 minutos vía systemd timer.
# =============================================================================

ENV_FILE="/opt/docker-watch/.env"
source "$ENV_FILE"

: "${BOT_TOKEN:?missing BOT_TOKEN}"
: "${CHAT_ID:?missing CHAT_ID}"

SERVER_LABEL="${SERVER_LABEL:-$(hostname)}"
HOST="$(hostname -f 2>/dev/null || hostname)"
DATE="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# -----------------------------------------------------------------------------
# Telegram sender robusto
# -----------------------------------------------------------------------------

tg_send() {
  local text="$1"

  resp="$(curl -sS -w "\nHTTP_STATUS=%{http_code}\n" --max-time 10 \
    -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "parse_mode=HTML" \
    --data-urlencode "text=${text}" \
    -d "disable_web_page_preview=true" || true)"

  echo "$resp" | grep -q "HTTP_STATUS=200" && return 0

  echo "Telegram error:" >&2
  echo "$resp" >&2
  return 1
}

esc() {
  sed -e 's/&/\&amp;/g' \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g'
}

ALERTS=""

# =============================================================================
# 1️⃣ Verificar Docker daemon
# =============================================================================

if ! systemctl is-active --quiet docker; then
  ALERTS="${ALERTS}
🔴 <b>DOCKER DAEMON DOWN</b>"
fi

# =============================================================================
# 2️⃣ Verificar docker-watch.service
# =============================================================================

if ! systemctl is-active --quiet docker-watch.service; then
  ALERTS="${ALERTS}
🔴 <b>DOCKER WATCHER DOWN</b>"
fi

# =============================================================================
# 3️⃣ Verificar contenedores monitoreados
# =============================================================================

LABEL_FILTER=()
if [[ -n "${MONITOR_LABEL_KEY:-}" && -n "${MONITOR_LABEL_VALUE:-}" ]]; then
  LABEL_FILTER+=(--filter "label=${MONITOR_LABEL_KEY}=${MONITOR_LABEL_VALUE}")
fi

# Lista de contenedores esperados (por label)
EXPECTED="$(docker ps -a "${LABEL_FILTER[@]}" --format '{{.Names}}|{{.Status}}' 2>/dev/null || true)"

if [[ -n "${EXPECTED// }" ]]; then
  while IFS='|' read -r name status; do
    [[ -z "$name" ]] && continue

    # Si no está running
    if [[ "$status" != Up* ]]; then
      ALERTS="${ALERTS}
🔴 <b>CONTAINER NOT RUNNING</b>
📦 <code>$(printf "%s" "$name" | esc)</code>
Estado: $(printf "%s" "$status" | esc)"
    fi

    # Unhealthy
    if [[ "$status" == *"(unhealthy)"* ]]; then
      ALERTS="${ALERTS}
🟠 <b>CONTAINER UNHEALTHY</b>
📦 <code>$(printf "%s" "$name" | esc)</code>"
    fi

  done <<< "$EXPECTED"
fi

# =============================================================================
# 4️⃣ Enviar alerta si existe problema
# =============================================================================

if [[ -n "$ALERTS" ]]; then

  MSG="<b>🚨 DOCKER ALERT</b>
🏷️ <b>$(printf "%s" "$SERVER_LABEL" | esc)</b>
🖥️ $(printf "%s" "$HOST" | esc)
🕒 $(printf "%s" "$DATE" | esc)

${ALERTS}
"

  tg_send "$MSG" || true
fi

exit 0
