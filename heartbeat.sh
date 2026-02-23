#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/docker-watch"
source "${BASE_DIR}/.env"
source "${BASE_DIR}/lib/telegram.sh"

: "${MONITOR_LABEL:?Falta MONITOR_LABEL}"

STATE_DIR="${DOCKER_WATCH_STATE_DIR:-/var/lib/docker-watch}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/docker-watch}"

mkdir -p "${STATE_DIR}" "${RUNTIME_DIR}"

# Lock + anti-duplicados diario (estilo Boot)
exec 9>"${RUNTIME_DIR}/heartbeat.lock"
flock -n 9 || { echo "SKIP: heartbeat ya corriendo" >&2; exit 0; }

STAMP_FILE="${STATE_DIR}/last_heartbeat_date"
TODAY="$(date +%F)"
HEARTBEAT_FORCE="${HEARTBEAT_FORCE:-false}"

if [[ -f "$STAMP_FILE" ]] && [[ "$(cat "$STAMP_FILE" 2>/dev/null || true)" == "$TODAY" ]] && [[ "$HEARTBEAT_FORCE" != "true" ]]; then
  echo "SKIP: heartbeat ya enviado hoy" >&2
  exit 0
fi

HOST="$(hostname)"
TS="$(date '+%Y-%m-%d %H:%M:%S %z')"

# Engine totals
engine_running=$(docker ps --format '{{.Names}}' | wc -l)
engine_total=$(docker ps -a --format '{{.Names}}' | wc -l)
engine_exited=$((engine_total - engine_running))

# Monitoreados
mon_total=$(docker ps -a --filter "label=${MONITOR_LABEL}" --format '{{.Names}}' | wc -l)
mon_running=$(docker ps --filter "label=${MONITOR_LABEL}" --format '{{.Names}}' | wc -l)
mon_unhealthy=$(docker ps --filter "label=${MONITOR_LABEL}" --filter "health=unhealthy" --format '{{.Names}}' | wc -l)
mon_stopped=$((mon_total - mon_running))

running_list=$(docker ps --filter "label=${MONITOR_LABEL}" --format '{{.Names}} — {{.Status}}')
unhealthy_list=$(docker ps --filter "label=${MONITOR_LABEL}" --filter "health=unhealthy" --format '{{.Names}} — {{.Status}}')
# stopped = NO "Up" (pero incluye "Exited" y "Created")
stopped_list=$(docker ps -a --filter "label=${MONITOR_LABEL}" --format '{{.Names}} — {{.Status}}' | grep -v '^$' | grep -v '— Up' || true)

# Top restarts
TOPN="${HEARTBEAT_TOP_RESTARTERS:-3}"
top_restarts=$(docker ps -a --filter "label=${MONITOR_LABEL}" --format '{{.Names}}' | while read -r c; do
  [[ -z "$c" ]] && continue
  rc=$(docker inspect -f '{{.RestartCount}}' "$c" 2>/dev/null || echo 0)
  echo "$c — restarts: $rc"
done | awk -F': ' '$2>0' | sort -t: -k2 -nr | head -n "$TOPN" )

# Mensaje
msg="<b>💓 DOCKER HEARTBEAT</b>
<i>${HOST} | ${TS}</i>

<b>📦 Engine</b>
• Running: ${engine_running} | Exited: ${engine_exited} | Total: ${engine_total}

<b>🏷 Monitoreados</b>
• ✅ running: ${mon_running} • 🟠 unhealthy: ${mon_unhealthy} • 🔴 stopped: ${mon_stopped}
"

if [[ -n "$running_list" ]]; then
  msg="${msg}

<b>✅ Running</b>
<pre>$(tg_escape_html "$running_list")</pre>"
fi

if [[ -n "$unhealthy_list" ]]; then
  msg="${msg}

<b>🟠 Unhealthy</b>
<pre>$(tg_escape_html "$unhealthy_list")</pre>"
fi

if [[ -n "$stopped_list" ]]; then
  msg="${msg}

<b>🔴 Stopped</b>
<pre>$(tg_escape_html "$stopped_list")</pre>"
fi

if [[ -n "$top_restarts" ]]; then
  msg="${msg}

<b>🔁 Top restarters</b>
<pre>$(tg_escape_html "$top_restarts")</pre>"
fi

msg="${msg}

<b>🔎 Diagnóstico</b>
<pre>systemctl status docker-watch.service --no-pager
docker ps -a --filter label=${MONITOR_LABEL}</pre>
"

# Alerts-only (opcional)
HEARTBEAT_ALERTS_ONLY="${HEARTBEAT_ALERTS_ONLY:-false}"
if [[ "$HEARTBEAT_ALERTS_ONLY" == "true" ]] && (( mon_unhealthy == 0 )) && (( mon_stopped == 0 )); then
  echo "SKIP: alerts-only y no hay issues" >&2
  echo "$TODAY" >"$STAMP_FILE"
  exit 0
fi

tg_send_message "$msg" >/dev/null

echo "$TODAY" >"$STAMP_FILE"
