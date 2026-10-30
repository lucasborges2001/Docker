#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
base_time_now_iso() { printf '2026-10-30T17:08:00Z\n'; }
source "$DIR/lib/shell/events.sh"
EVENT="$(docker_event_parse '{"status":"die","timeNano":1793370000000000000,"Actor":{"ID":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","Attributes":{"name":"api"}}}')"
EVENT="$EVENT" python3 - <<'PY'
import json, os
x = json.loads(os.environ['EVENT'])
assert x['container_id'] == 'a' * 64, 'Docker Actor.ID not normalized'
assert x['incident_key'] == 'api:die'
assert x['raw']['Actor']['ID'] == 'a' * 64
print('docker_event_actor_id_test PASS')
PY
