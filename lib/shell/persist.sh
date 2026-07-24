#!/usr/bin/env bash
if [[ -n "${DOCKER_PERSIST_SH_INCLUDED:-}" ]]; then return 0 2>/dev/null || exit 0; fi
DOCKER_PERSIST_SH_INCLUDED=1

docker_persist_snapshot() {
  local json="${1:?}" summary="${2:?}" dir="${3:-${DOCKER_WATCH_REPORTS_DIR:-/var/lib/docker-watch/reports}}" stamp report latest tmp
  stamp="$(date -u '+%Y%m%dT%H%M%SZ')"; report="${dir%/}/$stamp"; latest="${dir%/}/latest"
  mkdir -p "$report" "$latest"
  tmp="$report/report.json.tmp.$$"; printf '%s\n' "$json" > "$tmp"; mv -f "$tmp" "$report/report.json"
  tmp="$report/summary.txt.tmp.$$"; printf '%s\n' "$summary" > "$tmp"; mv -f "$tmp" "$report/summary.txt"
  cp "$report/report.json" "$latest/report.json.tmp.$$"; mv -f "$latest/report.json.tmp.$$" "$latest/report.json"
  cp "$report/summary.txt" "$latest/summary.txt.tmp.$$"; mv -f "$latest/summary.txt.tmp.$$" "$latest/summary.txt"
}

docker_rotate_event_log() {
  local log="${1:?}" max_bytes="${DOCKER_WATCH_EVENTS_MAX_BYTES:-10485760}" keep="${DOCKER_WATCH_EVENTS_RETENTION_FILES:-5}" size index
  [[ "$max_bytes" =~ ^[0-9]+$ ]] || max_bytes=10485760; [[ "$keep" =~ ^[0-9]+$ ]] || keep=5; (( keep > 20 )) && keep=20
  [[ -f "$log" ]] || return 0; size="$(wc -c < "$log" | tr -d ' ')"; (( size < max_bytes )) && return 0
  for ((index=keep; index>=1; index--)); do
    (( index == keep )) && rm -f -- "$log.$index"
    if (( index > 1 )) && [[ -f "$log.$((index-1))" ]]; then mv -f -- "$log.$((index-1))" "$log.$index"; fi
  done
  mv -f -- "$log" "$log.1"
}

docker_persist_event() {
  local event="${1:?}" log="${2:-${DOCKER_WATCH_EVENTS_LOG:-/var/log/docker-watch/events.jsonl}}"
  mkdir -p "$(dirname "$log")"; docker_rotate_event_log "$log"; printf '%s\n' "$event" >> "$log"
}

docker_update_latest_symlink() { return 0; }

docker_prune_old_reports() {
  local dir="${1:-${DOCKER_WATCH_REPORTS_DIR:-/var/lib/docker-watch/reports}}" days="${2:-${DOCKER_TELEMETRY_HISTORY_RETENTION_DAYS:-${DOCKER_WATCH_RETENTION_DAYS:-30}}}" max_snapshots="${3:-${DOCKER_TELEMETRY_HISTORY_MAX_SNAPSHOTS:-10000}}" max_bytes="${4:-${DOCKER_TELEMETRY_HISTORY_MAX_BYTES:-268435456}}"
  REPORTS_DIR="$dir" RETENTION_DAYS="$days" MAX_SNAPSHOTS="$max_snapshots" MAX_BYTES="$max_bytes" python3 - <<'PY'
import os,pathlib,re,shutil,time
root=pathlib.Path(os.environ['REPORTS_DIR']).resolve()
if str(root) in {'/','.'} or len(root.parts)<3 or not root.is_dir(): raise SystemExit(0)
def integer(name,default,minimum,maximum):
 try: value=int(os.environ.get(name,default))
 except ValueError: value=default
 return max(minimum,min(maximum,value))
days=integer('RETENTION_DAYS',30,0,3650); maximum=integer('MAX_SNAPSHOTS',10000,1,1000000); max_bytes=integer('MAX_BYTES',268435456,1048576,1099511627776)
pattern=re.compile(r'^\d{8}T\d{6}Z$'); entries=[p for p in root.iterdir() if p.is_dir() and pattern.match(p.name)]; cutoff=time.time()-(days*86400)
for path in entries:
 if days>0 and path.stat().st_mtime<cutoff: shutil.rmtree(path)
entries=sorted((p for p in root.iterdir() if p.is_dir() and pattern.match(p.name)),key=lambda p:p.name,reverse=True)
for path in entries[maximum:]: shutil.rmtree(path)
entries=sorted((p for p in root.iterdir() if p.is_dir() and pattern.match(p.name)),key=lambda p:p.name,reverse=True)
def size(path): return sum(f.stat().st_size for f in path.rglob('*') if f.is_file())
total=sum(size(path) for path in entries)
for path in reversed(entries):
 if total<=max_bytes: break
 current=size(path); shutil.rmtree(path); total-=current
PY
}
