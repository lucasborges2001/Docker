#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
php "$DIR/public_html/api/health.php" >/dev/null
php "$DIR/public_html/api/latest.php" >/dev/null || true
php "$DIR/public_html/api/events.php" >/dev/null
echo "docker web smoke OK"
