#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${BASE_DIR:?BASE_DIR is required for tests}"
source "$BASE_DIR/lib/shell/env.sh"; source "$BASE_DIR/lib/shell/log.sh"; source "$BASE_DIR/lib/shell/json.sh"; source "$BASE_DIR/lib/shell/lock.sh"; source "$BASE_DIR/lib/shell/time.sh"; source "$BASE_DIR/lib/shell/telegram.sh"
source "$DIR/lib/shell/collect.sh"; source "$DIR/lib/shell/events.sh"; source "$DIR/lib/shell/incident.sh"; source "$DIR/lib/shell/render.sh"; source "$DIR/lib/shell/persist.sh"; source "$DIR/lib/shell/heartbeat.sh"

json="$(docker_collect_snapshot_json)"
tmp="$(mktemp)"; printf '%s\n' "$json" > "$tmp"
base_json_file_is_valid "$tmp"
[[ "$(base_json_get_string "$json" module)" == "docker" ]]
rm -f "$tmp"
echo "docker_collect_test OK"
