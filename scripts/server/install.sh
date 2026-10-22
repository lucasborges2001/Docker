#!/usr/bin/env bash
set -euo pipefail
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-/opt/docker-watch}"
BASE_DIR="${BASE_DIR:-/opt/base}"
block() { printf 'BLOCKED: %s\n' "$1" >&2; exit 2; }

# The systemd contracts contain fixed paths: alternate targets are unsafe.
[[ "$INSTALL_DIR" == /opt/docker-watch ]] || block "INSTALL_DIR must be /opt/docker-watch"
[[ "$EUID" -eq 0 ]] || block "installation requires root"
for bin in rsync systemctl install chmod; do
  command -v "$bin" >/dev/null 2>&1 || block "missing prerequisite: $bin"
done
for path in /opt /opt/docker-watch /etc/systemd /etc/systemd/system /etc/docker-watch /var/lib/docker-watch /var/log/docker-watch; do
  [[ ! -L "$path" ]] || block "symlink in installation path: $path"
done
[[ ! -L "$INSTALL_DIR/config" ]] || block "symlink in config directory"
[[ ! -L "$INSTALL_DIR/config/server.env" ]] || block "server.env must not be a symlink"
[[ ! -e "$INSTALL_DIR/.env" && ! -L "$INSTALL_DIR/.env" ]] || block "unmanaged .env exists; migrate it explicitly before installing"

# No unit is overwritten when its entrypoint drifts from the repository contract.
for spec in \
  'docker-watch.service|ExecStart=/opt/docker-watch/bin/docker-watch' \
  'docker-watch-telemetry.service|ExecStart=/opt/docker-watch/bin/docker-telemetry --loop' \
  'docker-watch-heartbeat.service|ExecStart=/opt/docker-watch/bin/docker-heartbeat' \
  'docker-watch-heartbeat.timer|Unit=docker-watch-heartbeat.service'; do
  unit="${spec%%|*}"
  expected="${spec#*|}"
  unit_path="/etc/systemd/system/$unit"
  [[ ! -L "$unit_path" ]] || block "unit is a symlink: $unit"
  if [[ -e "$unit_path" ]] && ! grep -Fxq -- "$expected" "$unit_path"; then
    block "legacy or drifted unit: $unit; inspect and cut over explicitly"
  fi
  [[ -f "$SRC_DIR/systemd/$unit" ]] || block "source unit missing: $unit"
done
[[ -f "$SRC_DIR/config/server.env.example" ]] || block "source server.env.example missing"
[[ ! -d "$BASE_DIR" ]] && echo "WARN: Base not found at $BASE_DIR. Set BASE_DIR before running services." >&2
command -v docker >/dev/null 2>&1 || echo "WARN: docker command not found. Watcher will degrade until Docker is installed." >&2

mkdir -p "$INSTALL_DIR" /var/lib/docker-watch/reports /var/lib/docker-watch/incidents /var/log/docker-watch /etc/docker-watch
# Never import local secrets, private keys or Python bytecode from the checkout.
rsync -a --exclude='.git' --exclude='dist' --exclude='.env' \
  --exclude='config/server.env' --exclude='*.pem' --exclude='*.key' \
  --exclude='__pycache__' --exclude='*.pyc' "$SRC_DIR/" "$INSTALL_DIR/"
# Preserve existing configuration contents while enforcing private permissions.
if [[ ! -f "$INSTALL_DIR/config/server.env" ]]; then
  install -m 0600 -- "$INSTALL_DIR/config/server.env.example" "$INSTALL_DIR/config/server.env"
else
  chmod 0600 -- "$INSTALL_DIR/config/server.env"
fi
chmod +x "$INSTALL_DIR/bin/"* "$INSTALL_DIR/libexec/"* "$INSTALL_DIR/scripts/server/"*.sh "$INSTALL_DIR/scripts/web/"*.sh "$INSTALL_DIR/scripts/dev/"*.sh "$INSTALL_DIR/docker-watch.sh" "$INSTALL_DIR/heartbeat.sh"
for unit in docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.service docker-watch-heartbeat.timer; do
  cp "$INSTALL_DIR/systemd/$unit" "/etc/systemd/system/$unit"
done
systemctl daemon-reload
systemctl enable docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.timer
echo "Docker Watch installed in $INSTALL_DIR. Review config/server.env and run installation-doctor.py --deployment before starting."
