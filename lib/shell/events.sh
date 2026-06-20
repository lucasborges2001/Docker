#!/usr/bin/env bash
if [[ -n "${DOCKER_EVENTS_SH_INCLUDED:-}" ]]; then return 0 2>/dev/null || exit 0; fi
DOCKER_EVENTS_SH_INCLUDED=1
docker_events_stream() { local lf="${MONITOR_LABEL:-dockwatch.monitor=true}"; [[ -n "$lf" ]] && "${DOCKER_BIN:-docker}" events --filter type=container --filter "label=${lf}" --format '{{json .}}' || "${DOCKER_BIN:-docker}" events --filter type=container --format '{{json .}}'; }
docker_event_parse() {
  local line="${1:-}" now; now="$(base_time_now_iso)"
  EVENT_LINE="$line" EVENT_NOW="$now" python3 - <<'PY'
import json, os, sys
line=os.environ.get('EVENT_LINE','').strip(); now=os.environ.get('EVENT_NOW')
try: raw=json.loads(line)
except Exception:
    print(json.dumps({"time":now,"type":"error","severity":"error","container_id":None,"container_name":None,"image":None,"labels":{},"message":"Invalid docker event JSON","incident_key":"unknown:error","raw":line}, ensure_ascii=False,separators=(',',':'))); sys.exit(0)
attrs=((raw.get('Actor') or {}).get('Attributes') or {}) if isinstance(raw.get('Actor'),dict) else (raw.get('attrs') or {})
typ=raw.get('status') or raw.get('Action') or raw.get('action') or 'unknown'
sev='info'
if typ in ('die','health_status: unhealthy','unhealthy'): sev='error'
elif typ in ('restart','stop'): sev='warning'
elif typ in ('health_status: healthy','healthy','start'): sev='ok'
name=attrs.get('name') or raw.get('container_name') or raw.get('name') or ''
cid=raw.get('id') or raw.get('ID') or raw.get('container_id') or ''
image=raw.get('from') or raw.get('image') or attrs.get('image') or ''
labels={k:v for k,v in attrs.items() if k not in ('name','image')}
msg={'die':'Container died','health_status: unhealthy':'Container unhealthy','unhealthy':'Container unhealthy','health_status: healthy':'Container healthy','healthy':'Container healthy','restart':'Container restarted','start':'Container started','stop':'Container stopped'}.get(typ,'Docker event: '+str(typ))
inc='unhealthy' if typ in ('health_status: unhealthy','unhealthy') else ('healthy' if typ in ('health_status: healthy','healthy') else typ)
print(json.dumps({"time":now,"type":typ,"severity":sev,"container_id":cid or None,"container_name":name or None,"image":image or None,"labels":labels,"message":msg,"incident_key":(name or cid or 'unknown')+':'+inc,"raw":raw}, ensure_ascii=False,separators=(',',':')))
PY
}
docker_event_should_monitor() {
  local event_json="${1:?}" label="${MONITOR_LABEL:-dockwatch.monitor=true}"; [[ -z "$label" ]] && return 0
  EVENT_JSON="$event_json" MONITOR_LABEL_VALUE="$label" python3 - <<'PY'
import json, os, sys
try: e=json.loads(os.environ['EVENT_JSON'])
except Exception: sys.exit(1)
label=os.environ.get('MONITOR_LABEL_VALUE','')
key,val=(label.split('=',1)+[None])[:2] if '=' in label else (label,None)
raw=e.get('raw') or {}; attrs=((raw.get('Actor') or {}).get('Attributes') or {}) if isinstance(raw.get('Actor'),dict) else {}
labels={**attrs, **(e.get('labels') or {})}
if key not in labels: sys.exit(1)
if val is not None and str(labels.get(key)) != val: sys.exit(1)
PY
}
docker_event_container_name() { base_json_get_string "${1:?}" 'container_name'; }
docker_event_container_labels() { base_json_get_string "${1:?}" 'labels'; }
