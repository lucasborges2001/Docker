#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${BASE_DIR:?BASE_DIR is required for tests}"
source "$BASE_DIR/lib/shell/env.sh"; source "$BASE_DIR/lib/shell/log.sh"; source "$BASE_DIR/lib/shell/json.sh"; source "$BASE_DIR/lib/shell/lock.sh"; source "$BASE_DIR/lib/shell/time.sh"; source "$BASE_DIR/lib/shell/telegram.sh"
source "$DIR/lib/shell/collect.sh"; source "$DIR/lib/shell/events.sh"; source "$DIR/lib/shell/incident.sh"; source "$DIR/lib/shell/render.sh"; source "$DIR/lib/shell/persist.sh"; source "$DIR/lib/shell/heartbeat.sh"

line='{"status":"die","id":"abc123","from":"alpine:latest","Actor":{"Attributes":{"name":"dw-test","dockwatch.monitor":"true"}}}'
event="$(docker_event_parse "$line")"
[[ "$(base_json_get_string "$event" type)" == "die" ]]
[[ "$(base_json_get_string "$event" container_name)" == "dw-test" ]]
docker_event_should_monitor "$event"
echo "docker_event_parse_test OK"
