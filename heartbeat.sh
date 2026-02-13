#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Docker Watch Heartbeat (daily) -> Telegram
# Installs to: /opt/docker-watch/heartbeat.sh
# Config:       /opt/docker-watch/.env
# Reports: list of monitored running containers + unhealthy subset
# ------------------------------------------------------------

source /opt/docker-watch/.env
: "${BOT_TOKEN:?missing BOT_TOKEN}"
: "${CHAT_ID:?missing CHAT_ID}"

HOST="$(hostname -f 2>/dev/null || hostname)"

label_filter=()
if [[ -n "${MONITOR_LABEL_KEY:-}" && -n "${MONITOR_LABEL_VALUE:-}" ]]; then
  label_filter+=(--filter "label=${MONITOR_LABEL_KEY}=${MONITOR_LABEL_VALUE}")
fi

all="$(docker ps "${label_filter[@]}" --format '{{.Names}}|{{.Status}}' || true)"
all_count="$(echo "$all" | sed '/^\s*$/d' | wc -l | tr -d ' ')"

unhealthy="$(docker ps "${label_filter[@]}" --filter health=unhealthy --format '{{.Names}} ({{.Status}})' || true)"
unhealthy_count="$(echo "$unhealthy" | sed '/^\s*$/d' | wc -l | tr -d ' ')"

if [[ -z "${all// }" ]]; then
  all_lines="(none)"
else
  all_lines="$(echo "$all" | awk -F'|' '{printf("- %s: %s\n", $1, $2)}')"
fi

if [[ -z "${unhealthy// }" ]]; then
  unhealthy_lines="(none)"
else
  unhealthy_lines="$(echo "$unhealthy" | awk '{printf("- %s\n", $0)}')"
fi

text="💓 Docker heartbeat (${HOST})
monitored_running=${all_count}
unhealthy=${unhealthy_count}

Monitored containers:
${all_lines}Unhealthy:
${unhealthy_lines}@ $(date -Is)"

curl -fsS --max-time 10   -d "chat_id=${CHAT_ID}"   --data-urlencode "text=${text}"   -d "disable_web_page_preview=true"   "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" >/dev/null
