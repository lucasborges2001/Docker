#!/usr/bin/env bash
set -euo pipefail
PURGE_DATA="${PURGE_DATA:-false}"
systemctl disable --now docker-watch.service docker-watch-heartbeat.timer 2>/dev/null || true
rm -f /etc/systemd/system/docker-watch.service /etc/systemd/system/docker-watch-heartbeat.service /etc/systemd/system/docker-watch-heartbeat.timer
systemctl daemon-reload 2>/dev/null || true
rm -rf /opt/docker-watch
[[ "$PURGE_DATA" == true ]] && rm -rf /var/lib/docker-watch /var/log/docker-watch /etc/docker-watch || echo "Kept data/log/env directories."
