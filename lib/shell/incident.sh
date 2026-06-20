#!/usr/bin/env bash
if [[ -n "${DOCKER_INCIDENT_SH_INCLUDED:-}" ]]; then return 0 2>/dev/null || exit 0; fi
DOCKER_INCIDENT_SH_INCLUDED=1
docker_incident_key() { base_json_get_string "${1:?}" 'incident_key' 2>/dev/null || echo 'unknown:error'; }
docker_incident_state_path() { local safe; safe="$(printf '%s' "${1:?}" | tr -c 'A-Za-z0-9_.:-' '_' | sed 's/:/_/g')"; printf '%s/incidents/%s.json\n' "${DOCKER_WATCH_STATE_DIR:-/var/lib/docker-watch}" "$safe"; }
docker_incident_is_open() { [[ -f "$(docker_incident_state_path "${1:?}")" ]]; }
docker_incident_open() { local p; p="$(docker_incident_state_path "${1:?}")"; mkdir -p "$(dirname "$p")"; INCIDENT_KEY="$1" EVENT_JSON="${2:?}" python3 - <<'PY' > "$p"
import json, os
try: e=json.loads(os.environ['EVENT_JSON'])
except Exception: e={}
print(json.dumps({"key":os.environ.get("INCIDENT_KEY"),"opened_at":e.get("time"),"updated_at":e.get("time"),"level":e.get("type"),"event":e}, ensure_ascii=False, indent=2))
PY
}
docker_incident_escalate() { docker_incident_open "$1" "$2"; }
docker_incident_close_silent() { rm -f "$(docker_incident_state_path "${1:?}")"; }
