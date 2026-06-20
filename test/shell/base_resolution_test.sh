#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${BASE_DIR:?BASE_DIR is required for this test}"
resolved="$("$DIR/bin/docker-watch-test" --resolve-base)"
[[ "$resolved" == "$BASE_DIR" ]]
echo "base_resolution_test OK"
