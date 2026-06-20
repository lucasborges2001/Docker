#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR"; mkdir -p dist
tar -czf dist/docker-server.tar.gz bin lib config scripts/server systemd README-INSTALL.md docker-watch.sh heartbeat.sh
printf 'dist/docker-server.tar.gz\n'
