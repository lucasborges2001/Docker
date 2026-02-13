#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# DOCKER WATCH
# -----------------------------------------------------------------------------
# Event-driven monitoring para entornos reales.
#
# Notifica únicamente eventos GRAVES:
#   🔴 container die
#   🔴 container stop (manual o inesperado)
#   🟠 container unhealthy
#   🔴 flapping (>=3 crashes en 5 min)
#
# No:
#   - auto-restart
#   - notifica start normales
#   - notifica healthy
#   - escucha exec events
#
# Requiere:
#   /opt/docker-watch/.env
#   BOT_TOKEN
#   CHAT_ID
#
# Ejecutado como servicio systemd (persistente).
# =============================================================================

# -----------------------------
# Configuración base
# -----------------------------

ENV_FILE="/opt/docker-watch/.env"
RUNDIR="/run/docker-watch"
LOCK_FILE="${RUNDIR}/lock"
FLAP_DIR="${RUNDIR}/flap"

mkdir -p "$RUNDIR" "$FLAP_DIR"
chmod 0750 "$RUNDIR" "$FLAP_DIR" || true

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${BOT_TOKEN:?missing BOT_TOKEN}"
: "${CHAT_ID:?missing CHAT_ID}"

SERVER_LABEL="${SERVER_LABEL:-$(hostname)}"
HOST="$(hostname -f 2>/dev/null || hostname)"

# -----------------------------
# Lock para evitar doble instancia
# -----------------------------

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# -----------------------------
# Envío robusto a Telegram
# -----------------------------

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

# Escape básico HTML (evita errores de parse)
esc() {
  sed -e 's/&/\&amp;/g' \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g'
}

# -----------------------------
# Detección de flapping
# -----------------------------
# Consideramos flapping si:
#   >= 3 eventos "die" en 300 segundos
# -----------------------------

check_flap() {
  local cid="$1"
  local now; now="$(date +%s)"
  local file="$FLAP_DIR/$cid"

  touch "$file"

  # Mantener solo timestamps últimos 5 minutos
  awk -v now="$now" 'now-$1 < 300 {print $1}' "$file" >"$file.tmp" || true
  mv "$file.tmp" "$file"

  echo "$now" >>"$file"

  local count
  count="$(wc -l <"$file" | tr -d ' ')"

  if (( count >= 3 )); then
    echo "FLAP"
  fi
}

# -----------------------------
# Filtro por label (recomendado)
# -----------------------------

LABEL_FILTER=()
if [[ -n "${MONITOR_LABEL_KEY:-}" && -n "${MONITOR_LABEL_VALUE:-}" ]]; then
  LABEL_FILTER+=(--filter "label=${MONITOR_LABEL_KEY}=${MONITOR_LABEL_VALUE}")
fi

# -----------------------------
# Eventos escuchados
# Solo eventos graves
# -----------------------------

docker events \
  --filter type=container \
  --filter event=die \
  --filter event=stop \
  --filter event=health_status \
  "${LABEL_FILTER[@]}" \
  --format '{{.Time}}|{{.Action}}|{{.Actor.ID}}|{{.Actor.Attributes.name}}|{{.Actor.Attributes.image}}|{{.Actor.Attributes.exitCode}}' |
while IFS='|' read -r ts action cid name image exit_code; do

  name="${name:-unknown}"
  image="${image:-unknown}"
  short_cid="${cid:0:12}"
  when_iso="$(date -d "@${ts}" -Is 2>/dev/null || echo "${ts}")"

  case "$action" in

    # ---------------------------------------------------------
    # 🔴 CONTAINER CRASH
    # ---------------------------------------------------------
    die)
      flap="$(check_flap "$cid" || true)"

      MSG="<b>🔴 CONTAINER CRASH</b>
🏷️ <b>$(printf "%s" "$SERVER_LABEL" | esc)</b>
🖥️ $(printf "%s" "$HOST" | esc)
🕒 $(printf "%s" "$when_iso" | esc)

📦 <code>$(printf "%s" "$name" | esc)</code>
🖼️ <code>$(printf "%s" "$image" | esc)</code>
🚪 Exit: <b>${exit_code:-?}</b>"

      if [[ "$flap" == "FLAP" ]]; then
        MSG="${MSG}

⚠️ <b>FLAPPING DETECTED (>=3 crashes en 5 min)</b>"
      fi

      tg_send "$MSG" || true
      ;;

    # ---------------------------------------------------------
    # 🔴 CONTAINER STOPPED
    # ---------------------------------------------------------
    stop)
      MSG="<b>🔴 CONTAINER STOPPED</b>
🏷️ <b>$(printf "%s" "$SERVER_LABEL" | esc)</b>
🖥️ $(printf "%s" "$HOST" | esc)
🕒 $(printf "%s" "$when_iso" | esc)

📦 <code>$(printf "%s" "$name" | esc)</code>"

      tg_send "$MSG" || true
      ;;

    # ---------------------------------------------------------
    # 🟠 UNHEALTHY
    # ---------------------------------------------------------
    health_status:unhealthy)
      MSG="<b>🟠 CONTAINER UNHEALTHY</b>
🏷️ <b>$(printf "%s" "$SERVER_LABEL" | esc)</b>
🖥️ $(printf "%s" "$HOST" | esc)
🕒 $(printf "%s" "$when_iso" | esc)

📦 <code>$(printf "%s" "$name" | esc)</code>"

      tg_send "$MSG" || true
      ;;
  esac

done
