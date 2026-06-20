#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
find "$DIR" -type f \( -name '*.sh' -o -path '*/bin/*' \) -exec chmod +x {} +
