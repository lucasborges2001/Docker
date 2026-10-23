#!/usr/bin/env python3
"""Render Docker Watch systemd units for an isolated ~/servidor/ layout.

Pure renderer: it never installs units, changes permissions, or runs systemctl.
The legacy /opt installer remains unchanged.
"""
import argparse
from pathlib import Path
import re
import sys


UNITS = (
    "docker-watch.service",
    "docker-watch-telemetry.service",
    "docker-watch-heartbeat.service",
    "docker-watch-heartbeat.timer",
)


def validate_root(value: str) -> Path:
    if not re.fullmatch(r"/home/[a-z_][a-z0-9_-]*/servidor", value):
        raise ValueError("root must be /home/<account>/servidor")
    root = Path(value)
    if any(part.is_symlink() for part in (root.parent.parent, root.parent, root)):
        raise ValueError("root or ancestor is a symlink")
    return root


def render(root: Path, unit: str) -> str:
    common = f"""User=dockwatch
Group=dockwatch
Environment=BASE_DIR={root}/current/base
Environment=DOCKER_WATCH_STATE_DIR={root}/state/docker
Environment=DOCKER_WATCH_REPORTS_DIR={root}/state/docker/reports
Environment=DOCKER_WATCH_EVENTS_LOG={root}/logs/docker/events.jsonl
EnvironmentFile=-{root}/config/docker/server.env
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths={root}/state/docker {root}/logs/docker
UMask=0027
"""
    commands = {
        "docker-watch.service": ("Docker Watch events", "docker-watch", ""),
        "docker-watch-telemetry.service": ("Docker container telemetry", "docker-telemetry", " --loop"),
        "docker-watch-heartbeat.service": ("Docker Watch daily heartbeat", "docker-heartbeat", ""),
    }
    if unit in commands:
        description, command, args = commands[unit]
        one_shot = unit == "docker-watch-heartbeat.service"
        service_type = "oneshot" if one_shot else "simple"
        restart = "" if one_shot else "Restart=always\nRestartSec=5s\n"
        install = "" if one_shot else "\n[Install]\nWantedBy=multi-user.target\n"
        return (f"""[Unit]
Description={description} (servidor layout)
Wants=network-online.target
After=network-online.target docker.service

[Service]
Type={service_type}
ExecStart={root}/current/docker/bin/{command}{args}
""" + common + restart + install)
    if unit == "docker-watch-heartbeat.timer":
        return """[Unit]
Description=Run Docker Watch daily heartbeat (servidor layout)

[Timer]
OnCalendar=*-*-* 08:00:00
Persistent=true
Unit=docker-watch-heartbeat.service

[Install]
WantedBy=timers.target
"""
    raise ValueError("unknown unit")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, help="absolute /home/<account>/servidor")
    parser.add_argument("--unit", choices=UNITS, required=True)
    args = parser.parse_args()
    try:
        root = validate_root(args.root)
        sys.stdout.write(render(root, args.unit))
    except ValueError as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    sys.exit(main())
