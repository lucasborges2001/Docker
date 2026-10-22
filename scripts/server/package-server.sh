#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR"; mkdir -p dist
tar --exclude='config/server.env' --exclude='*/.env' --exclude='*/__pycache__' --exclude='*.pyc' --exclude='*.pem' --exclude='*.key' -czf dist/docker-server.tar.gz bin lib libexec config scripts/server systemd README-INSTALL.md docker-watch.sh heartbeat.sh
printf 'dist/docker-server.tar.gz\n'
