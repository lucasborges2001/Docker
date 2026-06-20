#!/usr/bin/env bash
if [[ -n "${DOCKER_HEARTBEAT_SH_INCLUDED:-}" ]]; then return 0 2>/dev/null || exit 0; fi
DOCKER_HEARTBEAT_SH_INCLUDED=1
docker_heartbeat_state_file() { printf '%s/heartbeat.last\n' "${DOCKER_WATCH_STATE_DIR:-/var/lib/docker-watch}"; }
docker_heartbeat_should_send_today() { [[ "$(base_env_bool HEARTBEAT_ONCE_PER_DAY true)" != true ]] && return 0; [[ "$(cat "$(docker_heartbeat_state_file)" 2>/dev/null || true)" != "$(date -u '+%Y-%m-%d')" ]]; }
docker_heartbeat_build_snapshot() { docker_collect_snapshot_json; }
docker_heartbeat_send() { base_telegram_send_html "$(docker_render_heartbeat_telegram_html "${1:?}")"; }
docker_heartbeat_mark_sent() { local f; f="$(docker_heartbeat_state_file)"; mkdir -p "$(dirname "$f")"; date -u '+%Y-%m-%d' > "$f"; }
