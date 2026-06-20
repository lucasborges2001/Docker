#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR"; mkdir -p dist
tar -czf dist/docker-web.tar.gz back config database public_html docs README.md
printf 'dist/docker-web.tar.gz\n'
