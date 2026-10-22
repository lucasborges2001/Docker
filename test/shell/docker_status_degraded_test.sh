#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/lib/shell/collect.sh"

# Deterministic no-daemon snapshot: override only collector inputs.
base_time_now_iso() { printf '%s\n' '2026-10-22T18:00:00Z'; }
base_env_bool() { printf '%s\n' false; }
docker_collect_engine() { printf '{"available":%s,"version":"test"}\n' "$ENGINE_AVAILABLE_TEST"; }
docker_collect_containers() { printf '%s\n' '{"total":1,"running":1,"stopped":0,"unhealthy":0,"monitored":1}'; }
docker_collect_resource_telemetry() {
  printf '{"sampled_at":"2026-10-22T18:00:00Z","items":[],"aggregates":{},"errors":%s}\n' "$TELEMETRY_ERRORS"
}
systemctl() { return 1; }
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
export DOCKER_WATCH_STATE_DIR="$tmp"
export SEND_TELEGRAM=false

check_status() {
  local expected="$1" snapshot
  snapshot="$(docker_collect_snapshot_json)"
  SNAPSHOT="$snapshot" EXPECTED="$expected" python3 - <<'PY'
import json, os
item = json.loads(os.environ["SNAPSHOT"])
expected = os.environ["EXPECTED"]
assert item["status"]["overall"] == expected, item["status"]
assert item["status"]["severity"] == expected, item["status"]
if item["monitoring"]["errors"]:
    assert expected == "warning"
PY
}

export ENGINE_AVAILABLE_TEST=true TELEMETRY_ERRORS='[{"code":"stats_failed"}]'
check_status warning
export TELEMETRY_ERRORS='[{"code":"inspect_timeout"}]'
check_status warning
export TELEMETRY_ERRORS='[]'
check_status ok
export ENGINE_AVAILABLE_TEST=false
check_status warning
echo 'docker_status_degraded_test OK'
