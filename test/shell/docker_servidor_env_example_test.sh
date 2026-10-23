#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/config/servidor.env.example"
SRV=/home/tecnicosfivisa/servidor
for line in \
  "DOCKER_SERVIDOR_ROOT=$SRV" \
  "BASE_DIR=$SRV/current/base" \
  "DOCKER_WATCH_STATE_DIR=$SRV/state/docker" \
  "DOCKER_WATCH_REPORTS_DIR=$SRV/state/docker/reports" \
  "DOCKER_WATCH_EVENTS_LOG=$SRV/logs/docker/events.jsonl" \
  'SEND_TELEGRAM=false'; do
  [[ "$(grep -Fxc "$line" "$FILE")" == 1 ]] || { echo "FAIL: missing or duplicate Docker env line: $line" >&2; exit 1; }
done
if grep -Eq '^[[:space:]]*(TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID|BOT_TOKEN|CHAT_ID)=' "$FILE"; then
  echo 'FAIL: credentials must not be in Docker template' >&2; exit 1
fi
if grep -Eq '^([A-Z_]+)=/(opt|var/lib|var/log|etc)/' "$FILE"; then
  echo 'FAIL: legacy path in Docker servidor template' >&2; exit 1
fi
echo DOCKER_SERVIDOR_ENV_EXAMPLE_PASS
