#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DIR="${BASE_DIR:-/opt/base}" "$DIR/bin/docker-heartbeat" --no-telegram --force --print >/dev/null
echo "docker server smoke OK"
