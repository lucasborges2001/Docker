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

# Resolve only an incident for the same Docker instance, after a newer start event.
# Rename the original record to *.resolved: never count it as open, keep evidence.
docker_incident_resolve_on_start() {
  local event="${1:?}" key stem kind path
  key="$(docker_incident_key "$event")"
  stem="${key%:*}"
  for kind in die unhealthy; do
    path="$(docker_incident_state_path "$stem:$kind")"
    [[ -f "$path" && ! -L "$path" ]] || continue
    DOCKER_RECOVERY_EVENT="$event" DOCKER_INCIDENT_PATH="$path" DOCKER_INCIDENT_KIND="$kind" python3 - <<'PY' || return 1
import json, os, re, stat, sys

def identity(event):
    raw = event.get('raw') if isinstance(event.get('raw'), dict) else {}
    actor = raw.get('Actor') if isinstance(raw.get('Actor'), dict) else {}
    values = [event.get('container_id'), raw.get('id'), raw.get('ID'),
              raw.get('container_id'), actor.get('ID')]
    ids = []
    for value in values:
        if value is None or value == '':
            continue
        if not isinstance(value, str) or not re.fullmatch(r'[0-9a-fA-F]{12,64}', value):
            return None
        ids.append(value.lower())
    if not ids or any(not (a.startswith(b) or b.startswith(a)) for a in ids for b in ids):
        return None
    return max(ids, key=len)

def event_ns(event):
    raw = event.get('raw') if isinstance(event.get('raw'), dict) else {}
    nano = raw.get('timeNano')
    sec = raw.get('time')
    if type(nano) is int and nano > 0:
        return nano
    if type(sec) is int and sec > 0:
        return sec * 1_000_000_000
    return None

try:
    start = json.loads(os.environ['DOCKER_RECOVERY_EVENT'])
    path = os.environ['DOCKER_INCIDENT_PATH']
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as handle:
        info = os.fstat(handle.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid():
            sys.exit(1)
        incident = json.load(handle)
    if not isinstance(start, dict) or not isinstance(incident, dict):
        sys.exit(0)
    died = incident.get('event')
    expected = {'die': ('die',), 'unhealthy': ('unhealthy', 'health_status: unhealthy')}
    if not isinstance(died, dict) or died.get('type') not in expected[os.environ['DOCKER_INCIDENT_KIND']]:
        sys.exit(0)
    new_id, old_id = identity(start), identity(died)
    new_time, old_time = event_ns(start), event_ns(died)
    if (start.get('type') != 'start' or not new_id or not old_id
            or not (new_id.startswith(old_id) or old_id.startswith(new_id))
            or new_time is None or old_time is None or new_time <= old_time):
        sys.exit(0)
    dest = path + '.' + str(new_time) + '.resolved'
    current = os.stat(path, follow_symlinks=False)
    if (os.path.lexists(dest) or current.st_ino != info.st_ino
            or current.st_dev != info.st_dev):
        sys.exit(1)
    os.rename(path, dest)
except (OSError, ValueError, TypeError, KeyError):
    sys.exit(1)
PY
  done
}
