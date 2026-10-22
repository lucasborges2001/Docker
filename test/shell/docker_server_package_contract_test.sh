#!/usr/bin/env bash
# A disposable archive validates the server payload without touching production.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"/{bin,lib,libexec,config,scripts/server,systemd}
cp "$ROOT/scripts/server/package-server.sh" "$TMP/scripts/server/package-server.sh"
printf '#!/usr/bin/env bash\n' > "$TMP/bin/docker-telemetry"
printf 'runner\n' > "$TMP/libexec/docker-telemetry-runner.py"
printf 'collector\n' > "$TMP/libexec/docker-telemetry-collector.py"
printf 'SECRET\n' > "$TMP/config/server.env"
printf 'SECRET\n' > "$TMP/config/.env"
mkdir -p "$TMP/libexec/__pycache__"
printf 'bytecode\n' > "$TMP/libexec/__pycache__/collector.pyc"
touch "$TMP/README-INSTALL.md" "$TMP/docker-watch.sh" "$TMP/heartbeat.sh"
for folder in lib config systemd; do touch "$TMP/$folder/.test-fixture"; done
bash "$TMP/scripts/server/package-server.sh" >/dev/null
PACKAGE="$TMP/dist/docker-server.tar.gz"
[[ -f "$PACKAGE" ]]
CONTENTS="$(tar -tzf "$PACKAGE")"
for required in \
  libexec/docker-telemetry-runner.py \
  libexec/docker-telemetry-collector.py \
  bin/docker-telemetry; do
  grep -Fxq "$required" <<<"$CONTENTS" || {
    echo "FAIL: server package lacks $required" >&2
    exit 1
  }
done
for forbidden in config/server.env config/.env libexec/__pycache__/collector.pyc; do
  if grep -Fxq "$forbidden" <<<"$CONTENTS"; then
    echo "FAIL: server package leaks $forbidden" >&2
    exit 1
  fi
done
echo DOCKER_SERVER_PACKAGE_CONTRACT_PASS
