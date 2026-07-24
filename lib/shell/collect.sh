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
import json,os
print(json.dumps({"available":os.environ.get("ENGINE_AVAILABLE")=="true","version":os.environ.get("ENGINE_VERSION") or None,"socket":os.environ.get("ENGINE_SOCKET") or "/var/run/docker.sock","socket_resolved":bool(os.environ.get("ENGINE_SOCKET"))},ensure_ascii=False,separators=(",",":")))
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
import json,os
i=lambda n:int(os.environ.get(n) or 0)
print(json.dumps({"total":i("TOTAL"),"running":i("RUNNING"),"stopped":i("STOPPED"),"unhealthy":i("UNHEALTHY"),"monitored":i("MONITORED")},separators=(",",":")))
PY
}
docker_collect_resource_telemetry() {
  local collector
  if [[ "$(base_env_bool DOCKER_TELEMETRY_ENABLED true)" != true ]]; then echo '{"sampled_at":null,"engine":{"available":false,"version":null},"items":[],"aggregates":{},"errors":[]}'; return 0; fi
  collector="${DOCKER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/libexec/docker-telemetry-collector.py"
  [[ -f "$collector" ]] || { echo '{"sampled_at":null,"engine":{"available":false,"version":null},"items":[],"aggregates":{},"errors":[{"code":"collector_missing"}]}'; return 0; }
  python3 "$collector" 2>/dev/null || echo '{"sampled_at":null,"engine":{"available":false,"version":null},"items":[],"aggregates":{},"errors":[{"code":"collector_failed"}]}'
}
docker_collect_monitored_containers() { docker_engine_available || { echo '[]'; return 0; }; _docker_cmd ps -a --filter "label=${MONITOR_LABEL:-dockwatch.monitor=true}" --format '{{json .}}' 2>/dev/null | python3 -c 'import sys,json; print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()],ensure_ascii=False,separators=(",",":")))'; }
docker_collect_unhealthy() { docker_engine_available || { echo '[]'; return 0; }; _docker_cmd ps -a --filter health=unhealthy --format '{{json .}}' 2>/dev/null | python3 -c 'import sys,json; print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()],ensure_ascii=False,separators=(",",":")))'; }
docker_collect_stopped() { docker_engine_available || { echo '[]'; return 0; }; _docker_cmd ps -a --filter status=exited --filter status=created --format '{{json .}}' 2>/dev/null | python3 -c 'import sys,json; print(json.dumps([json.loads(l) for l in sys.stdin if l.strip()],ensure_ascii=False,separators=(",",":")))'; }
docker_collect_top_restarters() {
  docker_engine_available || { echo '[]'; return 0; }
  _docker_cmd ps -a --format '{{.Names}}' 2>/dev/null | while read -r name; do [[ -n "$name" ]] || continue; printf '%s\t%s\n' "$(_docker_cmd inspect -f '{{.RestartCount}}' "$name" 2>/dev/null || echo 0)" "$name"; done | sort -nr | head -n 5 | python3 -c 'import json,sys
out=[]
for line in sys.stdin:
 p=line.rstrip("\n").split("\t",1)
 if len(p)!=2: continue
 try: count=int(p[0] or 0)
 except ValueError: count=0
 if count>0: out.append({"name":p[1],"restart_count":count})
print(json.dumps(out,ensure_ascii=False,separators=(",",":")))'
}
docker_collect_compose_projects() { docker_engine_available || { echo '[]'; return 0; }; _docker_cmd ps -a --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null | sed '/^$/d' | sort -u | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()],ensure_ascii=False,separators=(",",":")))'; }
docker_collect_snapshot_json() {
  local generated_at hostname engine containers telemetry open watcher heartbeat label telemetry_enabled include_unlabeled interval
  generated_at="$(base_time_now_iso)"; hostname="$(hostname 2>/dev/null || echo unknown)"; engine="$(docker_collect_engine)"; containers="$(docker_collect_containers)"; telemetry="$(docker_collect_resource_telemetry)"
  open="$(find "${DOCKER_WATCH_STATE_DIR:-/var/lib/docker-watch}/incidents" -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
  command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet docker-watch.service 2>/dev/null && watcher=true || watcher=false
  heartbeat="$(base_env_bool HEARTBEAT_ENABLED true)"; telemetry_enabled="$(base_env_bool DOCKER_TELEMETRY_ENABLED true)"; include_unlabeled="$(base_env_bool DOCKER_TELEMETRY_INCLUDE_UNLABELED false)"; label="${MONITOR_LABEL:-dockwatch.monitor=true}"; interval="${DOCKER_TELEMETRY_INTERVAL_SECONDS:-60}"
  GENERATED_AT="$generated_at" HOSTNAME_VALUE="$hostname" ENGINE_JSON="$engine" CONTAINERS_JSON="$containers" TELEMETRY_JSON="$telemetry" OPEN="$open" WATCHER="$watcher" HEARTBEAT="$heartbeat" TELEMETRY_ENABLED="$telemetry_enabled" INCLUDE_UNLABELED="$include_unlabeled" INTERVAL="$interval" LABEL="$label" REPORTS="${DOCKER_WATCH_REPORTS_DIR:-/var/lib/docker-watch/reports}" EVENTS="${DOCKER_WATCH_EVENTS_LOG:-/var/log/docker-watch/events.jsonl}" SEND_TELEGRAM="${SEND_TELEGRAM:-true}" python3 - <<'PY'
import json,os
def load(name,default):
 try:
  value=json.loads(os.environ.get(name,'')); return value if isinstance(value,type(default)) else default
 except Exception: return default
def boolean(value): return str(value).lower() in ('1','true','yes','on')
engine=load('ENGINE_JSON',{"available":False,"version":None,"socket":"/var/run/docker.sock","socket_resolved":False})
containers=load('CONTAINERS_JSON',{"total":0,"running":0,"stopped":0,"unhealthy":0,"monitored":0})
telemetry=load('TELEMETRY_JSON',{"sampled_at":None,"items":[],"aggregates":{},"errors":[{"code":"telemetry_invalid"}]})
items=telemetry.get('items') if isinstance(telemetry.get('items'),list) else []
aggregates=telemetry.get('aggregates') if isinstance(telemetry.get('aggregates'),dict) else {}
containers.update({"items":items,"without_memory_limit":int(aggregates.get('without_memory_limit') or 0),"without_healthcheck":int(aggregates.get('without_healthcheck') or 0)})
open_inc=int(os.environ.get('OPEN') or 0)
if not engine.get('available'): severity=overall='warning'; summary='Docker no disponible o inaccesible'
elif containers.get('unhealthy',0)>0 or open_inc>0: severity=overall='warning'; summary='Docker requiere atención'
else: severity=overall='ok'; summary='Docker estable'
try: interval=max(5,int(os.environ.get('INTERVAL') or 60))
except ValueError: interval=60
reports=os.environ.get('REPORTS') or '/var/lib/docker-watch/reports'; events=os.environ.get('EVENTS') or '/var/log/docker-watch/events.jsonl'
payload={"module":"docker","schema_version":2,"schema_compatibility":{"minimum":1,"current":2,"mode":"expand-only"},"generated_at":os.environ.get('GENERATED_AT'),"server":{"hostname":os.environ.get('HOSTNAME_VALUE') or 'unknown'},"status":{"overall":overall,"severity":severity,"summary":summary},"engine":engine,"containers":containers,"aggregates":aggregates,"monitoring":{"label":os.environ.get('LABEL') or 'dockwatch.monitor=true',"watcher_running":os.environ.get('WATCHER')=='true',"heartbeat_enabled":os.environ.get('HEARTBEAT')=='true',"telemetry_enabled":os.environ.get('TELEMETRY_ENABLED')=='true',"include_unlabeled":os.environ.get('INCLUDE_UNLABELED')=='true',"interval_seconds":interval,"sampled_at":telemetry.get('sampled_at'),"errors":telemetry.get('errors') if isinstance(telemetry.get('errors'),list) else []},"incidents":{"open":open_inc,"recent":[]},"top_restarters":aggregates.get('top_restarters',[]),"telegram":{"enabled":boolean(os.environ.get('SEND_TELEGRAM','true')),"last_send_ok":None,"message_id":None},"artifacts":{"report_json":reports.rstrip('/')+'/latest/report.json',"summary_txt":reports.rstrip('/')+'/latest/summary.txt',"events_jsonl":events}}
print(json.dumps(payload,ensure_ascii=False,indent=2))
PY
}
docker_snapshot_set_telegram_result() {
  SNAPSHOT_JSON="${1:?}" TELEGRAM_ENABLED_VALUE="${2:-false}" TELEGRAM_OK_VALUE="${3:-null}" TELEGRAM_MESSAGE_ID_VALUE="${4:-null}" TELEGRAM_ERROR_VALUE="${5:-}" python3 - <<'PY'
import json,os
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
print(json.dumps(s,ensure_ascii=False,indent=2))
PY
}
