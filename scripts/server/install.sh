#!/usr/bin/env bash
set -euo pipefail
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-/opt/docker-watch}"
BASE_DIR="${BASE_DIR:-/opt/base}"
[[ ! -d "$BASE_DIR" ]] && echo "WARN: Base not found at $BASE_DIR. Set BASE_DIR before running services." >&2
command -v docker >/dev/null 2>&1 || echo "WARN: docker command not found. Watcher will degrade until Docker is installed." >&2
mkdir -p "$INSTALL_DIR" /var/lib/docker-watch/reports /var/lib/docker-watch/incidents /var/log/docker-watch /etc/docker-watch
rsync -a --delete --exclude='.git' --exclude='dist' "$SRC_DIR/" "$INSTALL_DIR/"
[[ -f "$INSTALL_DIR/config/server.env" ]] || cp "$INSTALL_DIR/config/server.env.example" "$INSTALL_DIR/config/server.env"
chmod +x "$INSTALL_DIR/bin/"* "$INSTALL_DIR/scripts/server/"*.sh "$INSTALL_DIR/scripts/web/"*.sh "$INSTALL_DIR/scripts/dev/"*.sh "$INSTALL_DIR/docker-watch.sh" "$INSTALL_DIR/heartbeat.sh"
cp "$INSTALL_DIR/systemd/docker-watch.service" /etc/systemd/system/docker-watch.service
cp "$INSTALL_DIR/systemd/docker-watch-heartbeat.service" /etc/systemd/system/docker-watch-heartbeat.service
cp "$INSTALL_DIR/systemd/docker-watch-heartbeat.timer" /etc/systemd/system/docker-watch-heartbeat.timer
systemctl daemon-reload
systemctl enable docker-watch.service docker-watch-heartbeat.timer
echo "Docker Watch installed in $INSTALL_DIR. Edit config/server.env before starting."
