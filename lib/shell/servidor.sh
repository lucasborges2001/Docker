#!/usr/bin/env bash
# Docker Watch private servidor-layout guard. Call before sourcing Base or loading env files.
docker_servidor_config_guard() {
  local extra_env="${1:-}" root="" candidate
  DOCKER_SERVIDOR_ACTIVE=false
  if [[ "$DOCKER_DIR" =~ ^(/home/[a-z_][a-z0-9_-]*/servidor)/(current/docker|releases/docker/[0-9a-f]{40})$ ]]; then
    root="${BASH_REMATCH[1]}"
  elif [[ -n "${DOCKER_SERVIDOR_ROOT:-}" ]]; then
    root="$DOCKER_SERVIDOR_ROOT"
  fi
  [[ -n "$root" ]] || return 0

  if [[ ! "$root" =~ ^/home/[a-z_][a-z0-9_-]*/servidor$ ]]; then
    echo "Invalid Docker servidor root" >&2
    return 2
  fi
  if [[ -n "${DOCKER_SERVIDOR_ROOT:-}" && "$DOCKER_SERVIDOR_ROOT" != "$root" ]]; then
    echo "Docker servidor root mismatch" >&2
    return 2
  fi
  if [[ "${BASE_DIR:-}" != "$root/current/base" || \
        "${DOCKER_WATCH_STATE_DIR:-}" != "$root/state/docker" || \
        "${DOCKER_WATCH_REPORTS_DIR:-}" != "$root/state/docker/reports" || \
        "${DOCKER_WATCH_EVENTS_LOG:-}" != "$root/logs/docker/events.jsonl" ]]; then
    echo "Docker servidor requires managed BASE_DIR, STATE_DIR, REPORTS_DIR and EVENTS_LOG" >&2
    return 2
  fi
  if [[ -n "$extra_env" ]]; then
    echo "Docker servidor forbids --env; use the required systemd EnvironmentFile" >&2
    return 2
  fi
  for candidate in \
    /home \
    "${root%/servidor}" \
    "$root" \
    "$root/state" \
    "$root/state/docker" \
    "$root/state/docker/incidents" \
    "$root/state/docker/heartbeat.last" \
    "$root/state/docker/reports" \
    "$root/state/docker/reports/latest" \
    "$root/logs" \
    "$root/logs/docker" \
    "$root/logs/docker/events.jsonl"; do
    if [[ -L "$candidate" ]]; then
      echo "Docker servidor writable path must not be a symlink: $candidate" >&2
      return 2
    fi
  done
  DOCKER_SERVIDOR_ACTIVE=true
}
