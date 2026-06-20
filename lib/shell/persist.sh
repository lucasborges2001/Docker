#!/usr/bin/env bash
if [[ -n "${DOCKER_PERSIST_SH_INCLUDED:-}" ]]; then return 0 2>/dev/null || exit 0; fi
DOCKER_PERSIST_SH_INCLUDED=1
docker_persist_snapshot() { local json="${1:?}" summary="${2:?}" dir="${3:-${DOCKER_WATCH_REPORTS_DIR:-/var/lib/docker-watch/reports}}" stamp report latest; stamp="$(date -u '+%Y%m%dT%H%M%SZ')"; report="${dir%/}/$stamp"; latest="${dir%/}/latest"; mkdir -p "$report" "$latest"; printf '%s\n' "$json" > "$report/report.json"; printf '%s\n' "$summary" > "$report/summary.txt"; cp "$report/report.json" "$latest/report.json"; cp "$report/summary.txt" "$latest/summary.txt"; }
docker_persist_event() { local log="${2:-${DOCKER_WATCH_EVENTS_LOG:-/var/log/docker-watch/events.jsonl}}"; mkdir -p "$(dirname "$log")"; printf '%s\n' "${1:?}" >> "$log"; }
docker_update_latest_symlink() { return 0; }
docker_prune_old_reports() { local dir="${1:-${DOCKER_WATCH_REPORTS_DIR:-/var/lib/docker-watch/reports}}" days="${2:-${DOCKER_WATCH_RETENTION_DAYS:-14}}"; [[ -d "$dir" ]] || return 0; [[ "$days" =~ ^[0-9]+$ ]] || days=14; find "$dir" -mindepth 1 -maxdepth 1 -type d ! -name latest -mtime "+$days" -exec rm -rf {} + 2>/dev/null || true; }
