#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Docker Watch (event-based) -> Telegram
# Installs to: /opt/docker-watch/docker-watch.sh
# Config:       /opt/docker-watch/.env
# State (TTL/locks): /run/docker-watch (systemd RuntimeDirectory)
# ------------------------------------------------------------

ENV_FILE="/opt/docker-watch/.env"
RUNDIR="/run/docker-watch"
LOCK_FILE="${RUNDIR}/lock"
TTL_DIR="${RUNDIR}/ttl"
RST_DIR="${RUNDIR}/restarts"

mkdir -p "$RUNDIR" "$TTL_DIR" "$RST_DIR"
chmod 0750 "$RUNDIR" "$TTL_DIR" "$RST_DIR" || true

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${BOT_TOKEN:?missing BOT_TOKEN in $ENV_FILE}"
: "${CHAT_ID:?missing CHAT_ID in $ENV_FILE}"

HOST="$(hostname -f 2>/dev/null || hostname)"

send_telegram() {
  local text="$1"
  local url="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"

  # retry/backoff exponencial
  local attempt=1 max=6 sleep_s=1
  while (( attempt <= max )); do
    if curl -fsS --max-time 10       -d "chat_id=${CHAT_ID}"       --data-urlencode "text=${text}"       -d "disable_web_page_preview=true"       "$url" >/dev/null; then
      return 0
    fi
    sleep "$sleep_s"
    sleep_s=$(( sleep_s * 2 ))
    attempt=$(( attempt + 1 ))
  done
  return 1
}

ttl_ok() {
  local key="$1" ttl="$2"
  local f="$TTL_DIR/$key"
  local now; now="$(date +%s)"
  if [[ -f "$f" ]]; then
    local last; last="$(cat "$f" 2>/dev/null || echo 0)"
    if (( now - last < ttl )); then
      return 1
    fi
  fi
  echo "$now" >"$f"
  return 0
}

restart_allowed() {
  local cid="$1"
  local now; now="$(date +%s)"

  local cooldown="${RESTART_COOLDOWN_SEC:-120}"
  local perhour="${RESTART_MAX_PER_HOUR:-3}"

  local f="$RST_DIR/$cid"
  touch "$f"

  # conservar solo timestamps < 1h
  awk -v now="$now" 'now-$1 < 3600 {print $1}' "$f" >"$f.tmp" || true
  mv "$f.tmp" "$f"

  local count; count="$(wc -l <"$f" | tr -d ' ')"
  local last=0
  if [[ "$count" -gt 0 ]]; then
    last="$(tail -n1 "$f" || echo 0)"
  fi

  (( now - last < cooldown )) && return 1
  (( count >= perhour )) && return 1

  echo "$now" >>"$f"
  return 0
}

# Single instance (evita 2 watchers a la vez)
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# Filtro por label (recomendado)
LABEL_FILTER=()
if [[ -n "${MONITOR_LABEL_KEY:-}" && -n "${MONITOR_LABEL_VALUE:-}" ]]; then
  LABEL_FILTER+=(--filter "label=${MONITOR_LABEL_KEY}=${MONITOR_LABEL_VALUE}")
fi

# Eventos a escuchar
EVENT_FILTERS=(--filter type=container --filter event=die --filter event=health_status)
if [[ "${NOTIFY_START:-false}" == "true" ]]; then
  EVENT_FILTERS+=(--filter event=start)
fi

# Incluimos exitCode (solo aplica para 'die'; en otros puede venir vacío)
docker events "${EVENT_FILTERS[@]}" "${LABEL_FILTER[@]}"   --format '{{.Time}}|{{.Action}}|{{.Actor.ID}}|{{.Actor.Attributes.name}}|{{.Actor.Attributes.image}}|{{.Actor.Attributes.exitCode}}' | while IFS='|' read -r ts action cid name image exit_code; do

    name="${name:-unknown}"
    image="${image:-unknown}"
    short_cid="${cid:0:12}"

    # Docker suele emitir epoch en segundos. Convertimos a ISO si se puede.
    when_iso="$(date -d "@${ts}" -Is 2>/dev/null || echo "${ts}")"

    case "$action" in
      die)
        ttl="${TTL_DIE_SEC:-300}"
        key="die_${cid}"
        if ttl_ok "$key" "$ttl"; then
          msg="$(printf '🧯 Docker (%s)\ndie → %s\nimage: %s\ncid: %s\nexit: %s\n@ %s'             "$HOST" "$name" "$image" "$short_cid" "${exit_code:-?}" "$when_iso")"
          send_telegram "$msg" || true

          if [[ "${AUTO_RESTART_ON_DIE:-false}" == "true" ]]; then
            # (opcional) filtro extra para auto-restart por label:
            # AUTO_RESTART_LABEL_KEY / AUTO_RESTART_LABEL_VALUE
            if [[ -n "${AUTO_RESTART_LABEL_KEY:-}" && -n "${AUTO_RESTART_LABEL_VALUE:-}" ]]; then
              if [[ "$(docker inspect -f '{{ index .Config.Labels "'"${AUTO_RESTART_LABEL_KEY}"'" }}' "$cid" 2>/dev/null || true)" != "${AUTO_RESTART_LABEL_VALUE}" ]]; then
                continue
              fi
            fi

            if restart_allowed "$cid"; then
              docker start "$cid" >/dev/null 2>&1 || true
              msg="$(printf '🔁 Auto-restart (%s)\nstart → %s\ncid: %s\n@ %s'                 "$HOST" "$name" "$short_cid" "$when_iso")"
              send_telegram "$msg" || true
            else
              msg="$(printf '⏳ Auto-restart bloqueado (%s)\n(rate-limit/cooldown) → %s\ncid: %s\n@ %s'                 "$HOST" "$name" "$short_cid" "$when_iso")"
              send_telegram "$msg" || true
            fi
          fi
        fi
        ;;
      health_status:unhealthy)
        ttl="${TTL_UNHEALTHY_SEC:-600}"
        key="unhealthy_${cid}"
        if ttl_ok "$key" "$ttl"; then
          msg="$(printf '🟠 Docker (%s)\nunhealthy → %s\nimage: %s\ncid: %s\n@ %s'             "$HOST" "$name" "$image" "$short_cid" "$when_iso")"
          send_telegram "$msg" || true
        fi
        ;;
      health_status:healthy)
        if [[ "${NOTIFY_HEALTHY:-false}" == "true" ]]; then
          msg="$(printf '🟢 Docker (%s)\nhealthy → %s\n@ %s'             "$HOST" "$name" "$when_iso")"
          send_telegram "$msg" || true
        fi
        ;;
      start)
        ttl="${TTL_START_SEC:-600}"
        key="start_${cid}"
        if ttl_ok "$key" "$ttl"; then
          msg="$(printf '▶️ Docker (%s)\nstart → %s\nimage: %s\n@ %s'             "$HOST" "$name" "$image" "$when_iso")"
          send_telegram "$msg" || true
        fi
        ;;
    esac
  done
