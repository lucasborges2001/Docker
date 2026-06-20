#!/usr/bin/env bash
if [[ -n "${DOCKER_COLLECT_SH_INCLUDED:-}" ]]; then return 0 2>/dev/null || exit 0; fi
DOCKER_COLLECT_SH_INCLUDED=1
_docker_cmd() { "${DOCKER_BIN:-docker}" "$@"; }
docker_collect_socket() { [[ -S "${DOCKER_SOCKET:-/var/run/docker.sock}" ]] && printf '%s\n' "${DOCKER_SOCKET:-/var/run/docker.sock}" || { [[ -S /run/docker.sock ]] && printf '%s\n' /run/docker.sock || printf '%s\n' "${DOCKER_SOCKET:-/var/run/docker.sock}"; }; }
docker_engine_available() { command -v "${DOCKER_BIN:-docker}" >/dev/null 2>&1 && _docker_cmd version --format '{{.Server.Version}}' >/dev/null 2>&1; }
docker_collect_engine() {
  local available=false version="" socket; socket="$(docker_collect_socket)"
  if docker_engine_available; then available=true; version="$(_docker_cmd version --format '{{.Server.Version}}' 2>/dev/null || true)"; fi
  ENGINE_AVAILABLE="$available" ENGINE_VERSION="$version" ENGINE_SOCKET="$socket" python3 - <<'PY'
import json, os
print(json.dumps({"available":os.environ.get("ENGINE_AVAILABLE")=="true","version":os.environ.get("ENGINE_VERSION") or None,"socket":os.environ.get("ENGINE_SOCKET") or "/var/run/docker.sock"}, ensure_ascii=False, separators=(",",":")))
PY
}
docker_collect_containers() {
  local label_filter="${MONITOR_LABEL:-dockwatch.monitor=true}"
  if ! docker_engine_available; then echo '{"total":0,"running":0,"stopped":0,"unhealthy":0,"monitored":0}'; return 0; fi
  local total running stopped unhealthy monitored
  total="$(_docker_cmd ps -a -q 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')"
  running="$(_docker_cmd ps -q 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')"
  stopped="$(_docker_cmd ps -a --filter status=exited --filter status=created -q 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')"
  unhealthy="$(_docker_cmd ps -a --filter health=unhealthy -q 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ -n "$label_filter" ]] && monitored="$(_docker_cmd ps -a --filter "label=${label_filter}" -q 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')" || monitored="$total"
  TOTAL="$total" RUNNING="$running" STOPPED="$stopped" UNHEALTHY="$unhealthy" MONITORED="$monitored" python3 - <<'PY'
import json, os
i=lambda n:int(os.environ.get(n) or 0)
print(json.dumps({"total":i("TOTAL"),"running":i("RUNNING"),"stopped":i("STOPPED"),"unhealthy":i("UNHEALTHY"),"monitored":i("MONITORED")}, separators=(",",":")))
PY
}
docker_collect_monitored_containers() { docker_engine_available || { echo '[]'; return 0; }; _docker_cmd ps -a --filter "label=${MONITOR_LABEL:-dockwatch.monitor=true}" --format '{{json .}}' 2>/dev/null | python3 -c 'import sys,json; print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()],ensure_ascii=False,separators=(",",":")))'; }
docker_collect_unhealthy() { docker_engine_available || { echo '[]'; return 0; }; _docker_cmd ps -a --filter health=unhealthy --format '{{json .}}' 2>/dev/null | python3 -c 'import sys,json; print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()],ensure_ascii=False,separators=(",",":")))'; }
docker_collect_stopped() { docker_engine_available || { echo '[]'; return 0; }; _docker_cmd ps -a --filter status=exited --filter status=created --format '{{json .}}' 2>/dev/null | python3 -c 'import sys,json; print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()],ensure_ascii=False,separators=(",",":")))'; }
docker_collect_top_restarters() {
  docker_engine_available || { echo '[]'; return 0; }

  _docker_cmd ps -a --format '{{.Names}}' 2>/dev/null     | while read -r n; do
        [[ -n "$n" ]] || continue
        printf '%s\t%s\n' "$(_docker_cmd inspect -f '{{.RestartCount}}' "$n" 2>/dev/null || echo 0)" "$n"
      done     | sort -nr     | head -n 5     | python3 - <<'PY_RESTARTERS'
import json
import sys

out = []

for line in sys.stdin:
    parts = line.rstrip("\n").split("\t", 1)
    if len(parts) != 2:
        continue

    try:
        restart_count = int(parts[0] or 0)
    except ValueError:
        restart_count = 0

    if restart_count > 0:
        out.append({
            "name": parts[1],
            "restart_count": restart_count,
        })

print(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
PY_RESTARTERS
}
docker_collect_compose_projects() { docker_engine_available || { echo '[]'; return 0; }; _docker_cmd ps -a --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null | sed '/^$/d' | sort -u | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()],ensure_ascii=False,separators=(",",":")))'; }
docker_collect_snapshot_json() {
  local generated_at hostname engine containers restarters open watcher heartbeat label
  generated_at="$(base_time_now_iso)"; hostname="$(hostname 2>/dev/null || echo unknown)"
  engine="$(docker_collect_engine)"; containers="$(docker_collect_containers)"; restarters="$(docker_collect_top_restarters)"
  open="$(find "${DOCKER_WATCH_STATE_DIR:-/var/lib/docker-watch}/incidents" -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
  command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet docker-watch.service 2>/dev/null && watcher=true || watcher=false
  heartbeat="$(base_env_bool HEARTBEAT_ENABLED true)"; label="${MONITOR_LABEL:-dockwatch.monitor=true}"
  GENERATED_AT="$generated_at" HOSTNAME_VALUE="$hostname" ENGINE_JSON="$engine" CONTAINERS_JSON="$containers" TOP_JSON="$restarters" OPEN="$open" WATCHER="$watcher" HEARTBEAT="$heartbeat" LABEL="$label" REPORTS="${DOCKER_WATCH_REPORTS_DIR:-/var/lib/docker-watch/reports}" EVENTS="${DOCKER_WATCH_EVENTS_LOG:-/var/log/docker-watch/events.jsonl}" SEND_TELEGRAM="${SEND_TELEGRAM:-true}" python3 - <<'PY'
import json, os
def load(n,d):
    try: return json.loads(os.environ.get(n,''))
    except Exception: return d
engine=load('ENGINE_JSON',{"available":False,"version":None,"socket":"/var/run/docker.sock"})
containers=load('CONTAINERS_JSON',{"total":0,"running":0,"stopped":0,"unhealthy":0,"monitored":0})
top=load('TOP_JSON',[])
open_inc=int(os.environ.get('OPEN') or 0)
if not engine.get('available'): sev=overall='warning'; summary='Docker no disponible o inaccesible'
elif containers.get('unhealthy',0)>0 or open_inc>0: sev=overall='warning'; summary='Docker requiere atención'
else: sev=overall='ok'; summary='Docker estable'
reports=os.environ.get('REPORTS') or '/var/lib/docker-watch/reports'; events=os.environ.get('EVENTS') or '/var/log/docker-watch/events.jsonl'
print(json.dumps({"module":"docker","schema_version":1,"generated_at":os.environ.get('GENERATED_AT'),"server":{"hostname":os.environ.get('HOSTNAME_VALUE') or "unknown"},"status":{"overall":overall,"severity":sev,"summary":summary},"engine":engine,"containers":containers,"monitoring":{"label":os.environ.get('LABEL') or "dockwatch.monitor=true","watcher_running":os.environ.get('WATCHER')=="true","heartbeat_enabled":os.environ.get('HEARTBEAT')=="true"},"incidents":{"open":open_inc,"recent":[]},"top_restarters":top,"telegram":{"enabled":os.environ.get('SEND_TELEGRAM','true').lower() in ('1','true','yes','on'),"last_send_ok":None,"message_id":None},"artifacts":{"report_json":reports.rstrip('/')+"/latest/report.json","summary_txt":reports.rstrip('/')+"/latest/summary.txt","events_jsonl":events}}, ensure_ascii=False, indent=2))
PY
}
docker_snapshot_set_telegram_result() {
  SNAPSHOT_JSON="${1:?}" TELEGRAM_ENABLED_VALUE="${2:-false}" TELEGRAM_OK_VALUE="${3:-null}" TELEGRAM_MESSAGE_ID_VALUE="${4:-null}" TELEGRAM_ERROR_VALUE="${5:-}" python3 - <<'PY'
import json, os
s=json.loads(os.environ['SNAPSHOT_JSON'])
def b(v): return str(v).lower() in ('1','true','yes','on')
def nb(v):
    v=str(v).lower()
    if v in ('true','1'): return True
    if v in ('false','0'): return False
    return None
msg=os.environ.get('TELEGRAM_MESSAGE_ID_VALUE')
try: mid=None if msg in ('','null',None) else int(msg)
except Exception: mid=None
s['telegram']={"enabled":b(os.environ.get('TELEGRAM_ENABLED_VALUE')),"last_send_ok":nb(os.environ.get('TELEGRAM_OK_VALUE')),"message_id":mid}
if os.environ.get('TELEGRAM_ERROR_VALUE'): s['telegram']['error']=os.environ.get('TELEGRAM_ERROR_VALUE')
print(json.dumps(s, ensure_ascii=False, indent=2))
PY
}
