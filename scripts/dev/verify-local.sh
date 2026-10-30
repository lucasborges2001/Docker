#!/usr/bin/env bash
# Offline, deterministic subset of Docker Quality. No Docker daemon or Base required.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
MODE=compact
case "${1:---compact}" in
  --compact) ;;
  --verbose) MODE=verbose ;;
  --help|-h)
    printf 'Usage: bash scripts/dev/verify-local.sh [--compact|--verbose]\n'
    printf 'Offline lint and fixture contracts only; no Docker/systemd, deploy or GitHub Actions.\n'
    exit 0 ;;
  *) printf 'Invalid option: %s\n' "$1" >&2; exit 2 ;;
esac
if (($# > 1)); then printf 'Too many arguments\n' >&2; exit 2; fi
for binary in bash php python3 find xargs grep mktemp; do
  if ! command -v "$binary" >/dev/null 2>&1; then
    printf 'BLOCKED: missing required binary: %s\n' "$binary" >&2
    exit 2
  fi
done
TMP="$(mktemp -d "${TMPDIR:-/tmp}/docker-verify.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"
export PYTHONDONTWRITEBYTECODE=1
cd "$ROOT"
passed=0
failed=0
run_check() {
  local label="$1" log="$TMP/check-$((passed+failed+1)).log"
  shift
  if "$@" >"$log" 2>&1; then
    passed=$((passed+1))
    printf 'PASS %s\n' "$label"
    if [[ "$MODE" == verbose ]]; then cat -- "$log"; fi
  else
    failed=$((failed+1))
    printf 'FAIL %s\n' "$label" >&2
    # Failure detail is never suppressed, including compact mode.
    tail -n 45 -- "$log" >&2
  fi
}
php_syntax() { find . -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l; }
bash_syntax() {
  find . -type f -name '*.sh' -print0 | xargs -0 -r -n1 bash -n || return $?
  local file
  for file in bin/docker-watch bin/docker-heartbeat bin/docker-telemetry bin/docker-watch-test docker-watch.sh heartbeat.sh; do
    [[ ! -f "$file" ]] || bash -n "$file"
  done
}
python_syntax() {
  python3 -B -c 'import ast, pathlib; paths=list(pathlib.Path("libexec").glob("*.py"))+list(pathlib.Path("scripts/server").glob("*.py"))+list(pathlib.Path("test/python").glob("*.py")); [ast.parse(p.read_text(encoding="utf-8"), filename=str(p)) for p in paths]; print(f"checked {len(paths)} Python files")'
}
web_boundary() {
  if grep -RInE --include='*.php' --include='*.js' \
    'docker[[:space:]]+(start|stop|restart|kill|exec|rm|rmi)|shell_exec|exec\(|system\(|passthru|proc_open|popen' \
    public_html back; then
    printf 'Forbidden Docker mutation or execution in read-only web boundary\n' >&2
    return 1
  fi
}
run_check php_syntax php_syntax
run_check bash_syntax bash_syntax
run_check python_syntax python_syntax
run_check docker_actor_id bash test/shell/docker_event_actor_id_test.sh
run_check telemetry_fixture bash test/shell/docker_telemetry_collector_test.sh
run_check degraded_status bash test/shell/docker_status_degraded_test.sh
run_check counter_rates php test/php/DockerCounterRateTest.php
run_check trends php test/php/DockerTrendBuilderTest.php
run_check history_files php test/php/DockerHistoryFilesTest.php
run_check sample_data_guard php test/php/DockerPathsTest.php
run_check event_sanitization php test/php/DockerEventReaderTest.php
run_check installer_policy bash test/shell/docker_install_policy_test.sh
run_check servidor_units bash test/shell/docker_servidor_units_test.sh
run_check uninstall_dry_run bash test/shell/docker_uninstall_safety_test.sh
run_check storage_opt_in python3 -B -m unittest discover -s test/python -p '*storage_collector_test.py' -v
run_check server_package bash test/shell/docker_server_package_contract_test.sh
run_check installation_doctor python3 -B -m unittest discover -s test/python -p '*installation_doctor_test.py' -v
run_check api_path_guard bash test/shell/docker_public_paths_contract_test.sh
run_check web_boundary web_boundary
sha=UNKNOWN
status=not-a-git-checkout
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  sha="$(git -C "$ROOT" rev-parse --verify HEAD)"
  status=clean
  if [[ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]]; then status=dirty; fi
fi
printf 'DOCKER_VERIFY_SUMMARY passed=%d failed=%d sha=%s checkout=%s evidence=local-fixtures-only\n' "$passed" "$failed" "$sha" "$status"
((failed == 0))
