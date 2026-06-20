#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${BASE_DIR:?BASE_DIR is required for tests}"
source "$BASE_DIR/lib/shell/env.sh"; source "$BASE_DIR/lib/shell/log.sh"; source "$BASE_DIR/lib/shell/json.sh"; source "$BASE_DIR/lib/shell/lock.sh"; source "$BASE_DIR/lib/shell/time.sh"; source "$BASE_DIR/lib/shell/telegram.sh"
source "$DIR/lib/shell/collect.sh"; source "$DIR/lib/shell/events.sh"; source "$DIR/lib/shell/incident.sh"; source "$DIR/lib/shell/render.sh"; source "$DIR/lib/shell/persist.sh"; source "$DIR/lib/shell/heartbeat.sh"

json="$(cat "$DIR/var/sample-reports/latest/report.json")"
html="$(docker_render_heartbeat_telegram_html "$json")"
[[ "$html" == *"Docker heartbeat"* ]]
summary="$(docker_render_summary_text "$json")"
[[ "$summary" == *"Docker:"* ]]
echo "docker_render_test OK"
