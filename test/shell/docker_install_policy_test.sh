#!/usr/bin/env bash
# Static preflight contract only: never invoke installer against the CI host.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/scripts/server/install.sh"
bash -n "$FILE"
grep -Fq '[[ "$EUID" -eq 0 ]]' "$FILE"
grep -Fq 'INSTALL_DIR must be /opt/docker-watch' "$FILE"
grep -Fq "legacy or drifted unit" "$FILE"
grep -Fq "server.env must not be a symlink" "$FILE"
grep -Fq -- "--exclude='.env'" "$FILE"
grep -Fq -- "--exclude='config/server.env'" "$FILE"
grep -Fq -- "--exclude='*.pem'" "$FILE"
grep -Fq 'install -m 0600' "$FILE"
grep -Fq 'chmod 0600' "$FILE"
grep -Fq 'docker-watch-telemetry.service' "$FILE"
echo 'DOCKER_INSTALL_STATIC_POLICY_PASS (installer not executed)'
