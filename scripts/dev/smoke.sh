#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR"
find . -name '*.php' -print0 | xargs -0 -n1 php -l >/dev/null
for test in test/shell/*_test.sh; do bash "$test"; done
for test in test/php/*Test.php; do php "$test"; done
echo "Docker smoke OK"
