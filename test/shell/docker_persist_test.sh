#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${BASE_DIR:?BASE_DIR is required for tests}"
source "$BASE_DIR/lib/shell/env.sh"; source "$BASE_DIR/lib/shell/log.sh"; source "$BASE_DIR/lib/shell/json.sh"; source "$BASE_DIR/lib/shell/lock.sh"; source "$BASE_DIR/lib/shell/time.sh"; source "$BASE_DIR/lib/shell/telegram.sh"
source "$DIR/lib/shell/collect.sh"; source "$DIR/lib/shell/events.sh"; source "$DIR/lib/shell/incident.sh"; source "$DIR/lib/shell/render.sh"; source "$DIR/lib/shell/persist.sh"; source "$DIR/lib/shell/heartbeat.sh"

tmp="$(mktemp -d)"
json="$(cat "$DIR/var/sample-reports/latest/report.json")"
summary="$(docker_render_summary_text "$json")"
docker_persist_snapshot "$json" "$summary" "$tmp/reports"
[[ -f "$tmp/reports/latest/report.json" ]]
event="$(docker_event_parse '{"status":"heartbeat","Actor":{"Attributes":{"name":"hb","dockwatch.monitor":"true"}}}')"
docker_persist_event "$event" "$tmp/events.jsonl"
[[ -s "$tmp/events.jsonl" ]]
rm -rf "$tmp"
echo "docker_persist_test OK"
