#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${BASE_DIR:?BASE_DIR is required for tests}"
source "$BASE_DIR/lib/shell/env.sh"; source "$BASE_DIR/lib/shell/log.sh"; source "$BASE_DIR/lib/shell/json.sh"; source "$BASE_DIR/lib/shell/lock.sh"; source "$BASE_DIR/lib/shell/time.sh"; source "$BASE_DIR/lib/shell/telegram.sh"
source "$DIR/lib/shell/collect.sh"; source "$DIR/lib/shell/events.sh"; source "$DIR/lib/shell/incident.sh"; source "$DIR/lib/shell/render.sh"; source "$DIR/lib/shell/persist.sh"; source "$DIR/lib/shell/heartbeat.sh"

export DOCKER_WATCH_STATE_DIR="$(mktemp -d)"
event="$(docker_event_parse '{"status":"health_status: unhealthy","id":"abc","Actor":{"Attributes":{"name":"api","dockwatch.monitor":"true"}}}')"
key="$(docker_incident_key "$event")"
docker_incident_open "$key" "$event"
docker_incident_is_open "$key"
docker_incident_escalate "$key" "$event"
docker_incident_close_silent "$key"
! docker_incident_is_open "$key"
rm -rf "$DOCKER_WATCH_STATE_DIR"
echo "docker_incident_test OK"
