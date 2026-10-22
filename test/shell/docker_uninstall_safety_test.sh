#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/server/uninstall.sh"
bash -n "$SCRIPT"
plan="$(bash "$SCRIPT" --dry-run)"
grep -Fq 'DRY_RUN: no changes made' <<<"$plan"
grep -Fq 'docker-watch-telemetry.service' <<<"$plan"
grep -Fq 'Will preserve: /var/lib/docker-watch /var/log/docker-watch /etc/docker-watch' <<<"$plan"
purge="$(PURGE_DATA=true bash "$SCRIPT" --dry-run)"
grep -Fq 'Will purge: /var/lib/docker-watch /var/log/docker-watch /etc/docker-watch' <<<"$purge"
if bash "$SCRIPT" --apply >/dev/null 2>&1; then
  echo 'FAIL: unconfirmed apply was allowed' >&2; exit 1
fi
if PURGE_DATA=true bash "$SCRIPT" --apply --confirm docker-watch >/dev/null 2>&1; then
  echo 'FAIL: unconfirmed purge was allowed' >&2; exit 1
fi
if PURGE_DATA=/ bash "$SCRIPT" --dry-run >/dev/null 2>&1; then
  echo 'FAIL: invalid PURGE_DATA accepted' >&2; exit 1
fi
if bash "$SCRIPT" --apply --confirm wrong >/dev/null 2>&1; then
  echo 'FAIL: wrong confirmation accepted' >&2; exit 1
fi
echo 'DOCKER_UNINSTALL_SAFETY_PASS (plan-only, no destructive execution)'
