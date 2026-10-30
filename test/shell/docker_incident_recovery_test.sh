#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
base_time_now_iso() { printf '2026-10-30T17:08:00Z\n'; }
base_json_get_string() {
  VALUE="$1" FIELD="$2" python3 - <<'PY'
import os,json
v=json.loads(os.environ['VALUE'])
x=v.get(os.environ['FIELD'])
print(x if isinstance(x,str) else '')
PY
}
source "$DIR/lib/shell/events.sh"
source "$DIR/lib/shell/incident.sh"
DOCKER_WATCH_STATE_DIR="$(mktemp -d)"
export DOCKER_WATCH_STATE_DIR
trap 'rm -rf -- "$DOCKER_WATCH_STATE_DIR"' EXIT
ID_A="$(printf 'a%.0s' {1..64})"
ID_B="$(printf 'b%.0s' {1..64})"
raw() { printf '{"status":"%s","timeNano":%s,"Actor":{"ID":"%s","Attributes":{"name":"api","dockwatch.monitor":"true"}}}' "$1" "$2" "$3"; }
event_die="$(docker_event_parse "$(raw die 1793370000000000000 "$ID_A")")"
event_start="$(docker_event_parse "$(raw start 1793370001000000000 "$ID_A")")"
[[ "$(EVENT="$event_die" python3 -c 'import json,os; print(json.loads(os.environ["EVENT"])["container_id"])')" == "$ID_A" ]]
key="$(docker_incident_key "$event_die")"
path="$(docker_incident_state_path "$key")"
docker_incident_open "$key" "$event_die"
[[ -f "$path" ]]
docker_incident_resolve_on_start "$event_start"
[[ ! -f "$path" ]]
shopt -s nullglob
archived=("$path".*.resolved)
[[ ${#archived[@]} -eq 1 ]]
[[ "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["level"])' "${archived[0]}")" == die ]]
# Repeated start is idempotent.
docker_incident_resolve_on_start "$event_start"
[[ ${#archived[@]} -eq 1 ]]
# Newer failure must not be closed by earlier start; nor by reused name.
docker_incident_open "$key" "$event_die"
docker_incident_resolve_on_start "$(docker_event_parse "$(raw start 1793369999000000000 "$ID_A")")"
[[ -f "$path" ]]
docker_incident_resolve_on_start "$(docker_event_parse "$(raw start 1793370002000000000 "$ID_B")")"
[[ -f "$path" ]]
# No identity: fail closed.
docker_incident_resolve_on_start "$(docker_event_parse '{"status":"start","timeNano":1793370003000000000,"Actor":{"Attributes":{"name":"api"}}}')"
[[ -f "$path" ]]
# Old raw event with Actor.ID only is still correlatable.
docker_incident_resolve_on_start "$(docker_event_parse "$(raw start 1793370004000000000 "$ID_A")")"
[[ ! -f "$path" ]]
# Start also safely resolves an unhealthy incident from the same instance.
event_unhealthy="$(docker_event_parse "$(raw 'health_status: unhealthy' 1793370000000000000 "$ID_A")")"
ukey="$(docker_incident_key "$event_unhealthy")"
upath="$(docker_incident_state_path "$ukey")"
docker_incident_open "$ukey" "$event_unhealthy"
docker_incident_resolve_on_start "$event_start"
[[ ! -f "$upath" ]]
echo 'docker_incident_recovery_test PASS'
