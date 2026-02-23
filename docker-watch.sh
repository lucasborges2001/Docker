#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/docker-watch"

# --- Config ---
source "${BASE_DIR}/.env"
source "${BASE_DIR}/lib/telegram.sh"
source "${BASE_DIR}/lib/render.sh"

: "${MONITOR_LABEL:?Falta MONITOR_LABEL (ej: dockwatch.monitor=true)}"

STATE_DIR="${DOCKER_WATCH_STATE_DIR:-/var/lib/docker-watch}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/docker-watch}"
LOG_DIR="${DOCKER_WATCH_LOG_DIR:-/var/log/docker-watch}"
EVENTS_LOG="${DOCKER_WATCH_EVENTS_LOG:-${LOG_DIR}/events.jsonl}"

RECOVERY_GRACE_SEC="${RECOVERY_GRACE_SEC:-300}"
REAP_EVERY_SEC="${REAP_EVERY_SEC:-60}"

# Anti-spam (solo 1 alerta por incidente; edita si escala)
TTL_DIE_SEC="${TTL_DIE_SEC:-1800}"
TTL_UNHEALTHY_SEC="${TTL_UNHEALTHY_SEC:-3600}"
MAX_EDITS_PER_INCIDENT="${MAX_EDITS_PER_INCIDENT:-1}"

mkdir -p "${STATE_DIR}/incidents" "${RUNTIME_DIR}" "${LOG_DIR}"

# Lock global (evita 2 watchers simultáneos)
exec 9>"${RUNTIME_DIR}/watch.lock"
if ! flock -n 9; then
  echo "SKIP: ya hay una instancia corriendo" >&2
  exit 0
fi

HOST="$(hostname)"

parse_monitor_label() {
  local s="$1"
  # soporta KEY=VAL
  if [[ "$s" == *"="* ]]; then
    echo "${s%%=*}|${s#*=}"
  else
    # fallback: label completo sin valor
    echo "${s}|"
  fi
}

is_monitored() {
  local cid="$1"
  local kv key val got
  kv="$(parse_monitor_label "${MONITOR_LABEL}")"
  key="${kv%%|*}"
  val="${kv#*|}"

  got="$(docker inspect -f "{{ index .Config.Labels \"${key}\" }}" "${cid}" 2>/dev/null || true)"
  [[ -z "$got" || "$got" == "<no value>" ]] && return 1

  if [[ -n "$val" ]]; then
    [[ "$got" == "$val" ]]
  else
    return 0
  fi
}

now_epoch() { date +%s; }

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

audit_event() {
  # args: kind cid name action sent edited reason
  local kind="$1" cid="$2" name="$3" action="$4" sent="$5" edited="$6" reason="$7"
  local ts
  ts="$(date -Iseconds)"

  {
    printf '{"ts":%s,"host":%s,"kind":%s,"cid":%s,"name":%s,"action":%s,"sent":%s,"edited":%s,"reason":%s}\n' \
      "$(printf '%s' "$ts" | json_escape)" \
      "$(printf '%s' "$HOST" | json_escape)" \
      "$(printf '%s' "$kind" | json_escape)" \
      "$(printf '%s' "$cid" | json_escape)" \
      "$(printf '%s' "$name" | json_escape)" \
      "$(printf '%s' "$action" | json_escape)" \
      "$sent" \
      "$edited" \
      "$(printf '%s' "$reason" | json_escape)"
  } >>"$EVENTS_LOG" || true
}

incident_path() {
  local cid="$1"
  echo "${STATE_DIR}/incidents/${cid}"
}

incident_read() {
  local p="$1"
  [[ -f "$p" ]] || return 1
  # format: epoch|severity|message_id|edits
  cat "$p"
}

incident_write() {
  local p="$1" epoch="$2" sev="$3" mid="$4" edits="$5"
  printf '%s|%s|%s|%s\n' "$epoch" "$sev" "$mid" "$edits" >"$p"
}

sev_for_action() {
  local action="$1"
  case "$action" in
    die) echo 2 ;;
    health_status:*)
      if [[ "${action#health_status: }" == "unhealthy" ]]; then echo 1; else echo 0; fi
      ;;
    *) echo 0 ;;
  esac
}

ttl_for_sev() {
  local sev="$1"
  case "$sev" in
    2) echo "$TTL_DIE_SEC" ;;
    1) echo "$TTL_UNHEALTHY_SEC" ;;
    *) echo 0 ;;
  esac
}

should_suppress() {
  # args: incident_epoch incident_sev new_sev
  local ie="$1" is="$2" ns="$3"
  local now ttl
  now="$(now_epoch)"
  ttl="$(ttl_for_sev "$is")"

  # 1) incidente abierto => suprimir eventos del mismo o menor sev
  if (( ns <= is )); then
    # 2) si pasó TTL, permitimos volver a alertar (safety net)
    if (( ttl > 0 )) && (( now - ie >= ttl )); then
      return 1
    fi
    return 0
  fi

  # ns > is => no suprimir (permitimos escalación via edit)
  return 1
}

container_exit_code() {
  local cid="$1"
  docker inspect -f '{{.State.ExitCode}}' "$cid" 2>/dev/null || echo "?"
}

container_name() {
  local cid="$1"
  docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's#^/##' || true
}

container_health_status() {
  local cid="$1"
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$cid" 2>/dev/null || true
}

container_running() {
  local cid="$1"
  docker inspect -f '{{.State.Running}}' "$cid" 2>/dev/null || echo "false"
}

container_uptime_sec() {
  local cid="$1"
  local started now s_epoch
  started="$(docker inspect -f '{{.State.StartedAt}}' "$cid" 2>/dev/null || true)"
  [[ -z "$started" ]] && { echo 0; return; }
  s_epoch="$(date -d "$started" +%s 2>/dev/null || echo 0)"
  now="$(now_epoch)"
  if (( s_epoch <= 0 )); then echo 0; else echo $((now - s_epoch)); fi
}

reap_incidents() {
  local p cid line ie is mid edits
  shopt -s nullglob
  for p in "${STATE_DIR}/incidents"/*; do
    cid="$(basename "$p")"

    # si el contenedor no existe, limpiamos
    if ! docker inspect "$cid" >/dev/null 2>&1; then
      rm -f "$p" || true
      continue
    fi

    line="$(incident_read "$p" || true)"
    [[ -z "$line" ]] && continue

    ie="${line%%|*}"; line="${line#*|}"
    is="${line%%|*}"; line="${line#*|}"
    mid="${line%%|*}"; line="${line#*|}"
    edits="$line"

    # cierre silencioso si vuelve a healthy
    if [[ "$(container_health_status "$cid")" == "healthy" ]]; then
      rm -f "$p" || true
      continue
    fi

    # contenedores sin healthcheck: cierre si está Up estable > grace
    if [[ "$(container_health_status "$cid")" == "" ]] && [[ "$(container_running "$cid")" == "true" ]]; then
      if (( $(container_uptime_sec "$cid") >= RECOVERY_GRACE_SEC )); then
        rm -f "$p" || true
        continue
      fi
    fi
  done
}

handle_event() {
  local action="$1" cid="$2" name="$3"

  # gate por label
  if ! is_monitored "$cid"; then
    return 0
  fi

  local sev now p line ie is mid edits msg new_mid
  sev="$(sev_for_action "$action")"
  (( sev == 0 )) && return 0

  now="$(now_epoch)"
  p="$(incident_path "$cid")"
  name="${name:-$(container_name "$cid")}"
  [[ -z "$name" ]] && name="$cid"

  if [[ -f "$p" ]]; then
    line="$(incident_read "$p" || true)"
    if [[ -n "$line" ]]; then
      ie="${line%%|*}"; line="${line#*|}"
      is="${line%%|*}"; line="${line#*|}"
      mid="${line%%|*}"; line="${line#*|}"
      edits="$line"

      if should_suppress "$ie" "$is" "$sev"; then
        audit_event "event" "$cid" "$name" "$action" false false "suppressed" || true
        return 0
      fi

      # escalación: editar el MISMO mensaje (sin enviar uno nuevo)
      if (( sev > is )) && (( edits < MAX_EDITS_PER_INCIDENT )) && [[ -n "$mid" ]]; then
        local ts
        ts="$(date '+%Y-%m-%d %H:%M:%S %z')"

        if [[ "$action" == "die" ]]; then
          msg="$(render_alert_die "$HOST" "$ts" "$(tg_escape_html "$name")" "$(container_exit_code "$cid")")"
        else
          msg="$(render_alert_unhealthy "$HOST" "$ts" "$(tg_escape_html "$name")")"
        fi

        if tg_edit_message_text "$mid" "$msg"; then
          incident_write "$p" "$ie" "$sev" "$mid" $((edits + 1))
          audit_event "event" "$cid" "$name" "$action" false true "escalated_edit" || true
        else
          audit_event "event" "$cid" "$name" "$action" false false "edit_failed" || true
        fi
        return 0
      fi

      # TTL expiró: permitimos un nuevo mensaje (un nuevo incidente)
      rm -f "$p" || true
    fi
  fi

  # Nuevo incidente => un solo mensaje
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S %z')"

  if [[ "$action" == "die" ]]; then
    msg="$(render_alert_die "$HOST" "$ts" "$(tg_escape_html "$name")" "$(container_exit_code "$cid")")"
  else
    msg="$(render_alert_unhealthy "$HOST" "$ts" "$(tg_escape_html "$name")")"
  fi

  new_mid="$(tg_send_message "$msg")" || {
    echo "WARN: no se pudo enviar alerta Telegram (action=$action name=$name)" >&2
    audit_event "event" "$cid" "$name" "$action" false false "send_failed" || true
    return 1
  }

  incident_write "$p" "$now" "$sev" "$new_mid" 0
  audit_event "event" "$cid" "$name" "$action" true false "sent" || true
}

# --- Main loop ---
last_reap=0

echo "OK: docker-watch arrancó (label gate: ${MONITOR_LABEL})" >&2

while true; do
  # docker events se cae si reinicia docker; reconectamos
  while IFS='|' read -r _time _type action cid name; do
    # reap cada N segundos (barato, evita ruido por flapping)
    if (( $(now_epoch) - last_reap >= REAP_EVERY_SEC )); then
      reap_incidents || true
      last_reap="$(now_epoch)"
    fi

    case "$action" in
      die|health_status:*)
        handle_event "$action" "$cid" "$name" || true
        ;;
      *)
        :
        ;;
    esac
  done < <(docker events --filter type=container --format '{{.Time}}|{{.Type}}|{{.Action}}|{{.Actor.ID}}|{{.Actor.Attributes.name}}' 2>/dev/null)

  sleep 2
done
