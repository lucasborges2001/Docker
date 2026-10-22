#!/usr/bin/env python3
"""Read-only on-disk diagnosis of Docker Watch telemetry vs legacy watcher."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import stat
import sys

SERVICE = "etc/systemd/system/docker-watch.service"
TELEMETRY = "etc/systemd/system/docker-watch-telemetry.service"
BIN_WATCH = "opt/docker-watch/bin/docker-watch"
BIN_TELEMETRY = "opt/docker-watch/bin/docker-telemetry"
REPORT = "var/lib/docker-watch/reports/latest/report.json"
MAX_SIZE = 2097152


def command_probe(args: list[str], timeout: int, json_lines: bool = False) -> str:
    """Run only fixed, read-only argv; never expose stdout/stderr in the report."""
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
    except FileNotFoundError:
        return "BINARY_MISSING"
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    except OSError:
        return "EXEC_ERROR"
    if result.returncode != 0:
        error = result.stderr.lower()
        return "PERMISSION_DENIED" if "permission denied" in error else "COMMAND_FAILED"
    if json_lines:
        try:
            for line in result.stdout.splitlines():
                if line.strip() and not isinstance(json.loads(line), dict):
                    return "INVALID_JSON"
        except json.JSONDecodeError:
            return "INVALID_JSON"
    elif not result.stdout.strip():
        return "EMPTY_OUTPUT"
    return "PASS"


def probe_runtime(timeout: int = 10, docker_bin: str = "docker", systemctl_bin: str = "systemctl") -> dict:
    """Explicit runtime check. It neither restarts services nor changes Docker."""
    checks = {
        "docker_version": command_probe([docker_bin, "version", "--format", "{{.Server.Version}}"], timeout),
        "docker_ps": command_probe([docker_bin, "ps", "-a", "--format", "{{json .}}"], timeout, True),
        "docker_stats": command_probe([docker_bin, "stats", "--no-stream", "--all", "--format", "{{json .}}"], timeout, True),
    }
    for name, unit in (("watch_service", "docker-watch.service"),
                       ("telemetry_service", "docker-watch-telemetry.service")):
        try:
            result = subprocess.run([systemctl_bin, "is-active", "--quiet", unit],
                                    capture_output=True, text=True, timeout=timeout, check=False)
            checks[name] = "PASS" if result.returncode == 0 else "INACTIVE"
        except FileNotFoundError:
            checks[name] = "BINARY_MISSING"
        except subprocess.TimeoutExpired:
            checks[name] = "TIMEOUT"
        except OSError:
            checks[name] = "EXEC_ERROR"
    return {"status": "PASS" if all(value == "PASS" for value in checks.values()) else "FAIL",
            "checks": checks}




def deployment_state(root: Path) -> dict:
    """Filesystem-only deployment preflight: no socket, systemctl or secrets read."""
    checks: dict[str, str] = {}
    units = {
        "watch": ("etc/systemd/system/docker-watch.service", "ExecStart=/opt/docker-watch/bin/docker-watch"),
        "telemetry": ("etc/systemd/system/docker-watch-telemetry.service", "ExecStart=/opt/docker-watch/bin/docker-telemetry --loop"),
        "heartbeat": ("etc/systemd/system/docker-watch-heartbeat.service", "ExecStart=/opt/docker-watch/bin/docker-heartbeat"),
        "timer": ("etc/systemd/system/docker-watch-heartbeat.timer", "Unit=docker-watch-heartbeat.service"),
    }
    for key, (rel, expected) in units.items():
        file = root / rel
        try:
            if file.is_symlink():
                checks["unit_" + key] = "UNSAFE_SYMLINK"
            elif not file.is_file():
                checks["unit_" + key] = "MISSING"
            elif expected not in file.read_text(encoding="utf-8").splitlines():
                checks["unit_" + key] = "DRIFT"
            else:
                checks["unit_" + key] = "PASS"
        except (OSError, UnicodeError):
            checks["unit_" + key] = "UNREADABLE"
    for key, rel in {
        "binary_watch": "opt/docker-watch/bin/docker-watch",
        "binary_telemetry": "opt/docker-watch/bin/docker-telemetry",
        "binary_heartbeat": "opt/docker-watch/bin/docker-heartbeat",
        "doctor": "opt/docker-watch/scripts/server/installation-doctor.py",
    }.items():
        file = root / rel
        try:
            if file.is_symlink():
                checks[key] = "UNSAFE_SYMLINK"
            elif not file.is_file():
                checks[key] = "MISSING"
            elif key.startswith("binary_") and not (file.stat().st_mode & 0o111):
                checks[key] = "NOT_EXECUTABLE"
            else:
                checks[key] = "PASS"
        except OSError:
            checks[key] = "UNREADABLE"
    config = root / "opt/docker-watch/config/server.env"
    try:
        if config.is_symlink():
            checks["server_env"] = "UNSAFE_SYMLINK"
        elif not config.is_file():
            checks["server_env"] = "MISSING"
        elif stat.S_IMODE(config.stat().st_mode) & 0o077:
            checks["server_env"] = "INSECURE_PERMISSIONS"
        else:
            checks["server_env"] = "PASS"
    except OSError:
        checks["server_env"] = "UNREADABLE"
    for key, rel in {
        "state_dir": "var/lib/docker-watch",
        "log_dir": "var/log/docker-watch",
    }.items():
        directory = root / rel
        try:
            if directory.is_symlink():
                checks[key] = "UNSAFE_SYMLINK"
            else:
                checks[key] = "PASS" if directory.is_dir() else "MISSING"
        except OSError:
            checks[key] = "UNREADABLE"
    return {"status": "PASS" if all(value == "PASS" for value in checks.values()) else "FAIL",
            "checks": checks}



def state(root: Path, ttl: int, now: datetime) -> dict:
    checks = {}
    for name, rel, marker in [
        ("watch_unit", SERVICE, "ExecStart=/opt/docker-watch/bin/docker-watch"),
        ("telemetry_unit", TELEMETRY, "ExecStart=/opt/docker-watch/bin/docker-telemetry --loop"),
    ]:
        try:
            path = root / rel
            if not path.is_file():
                checks[name] = "MISSING"
            else:
                content = path.read_text(encoding="utf-8")
                checks[name] = "MATCH" if marker in content.splitlines() else "LEGACY_OR_DRIFT"
        except (OSError, UnicodeError):
            checks[name] = "UNREADABLE"
    for name, rel in [("watch_binary", BIN_WATCH), ("telemetry_binary", BIN_TELEMETRY)]:
        try:
            checks[name] = "PRESENT" if (root / rel).is_file() else "MISSING"
        except OSError:
            checks[name] = "UNREADABLE"

    report = root / REPORT
    checks["snapshot"] = "MISSING"
    try:
        if report.is_file():
            if report.stat().st_size > MAX_SIZE:
                checks["snapshot"] = "TOO_LARGE"
            else:
                value = json.loads(report.read_text(encoding="utf-8"))
                if not isinstance(value, dict) or value.get("module") != "docker" or value.get("schema_version") not in (1, 2):
                    checks["snapshot"] = "INVALID_CONTRACT"
                else:
                    observed = datetime.fromisoformat(str(value.get("generated_at", "")).replace("Z", "+00:00"))
                    age = (now - observed).total_seconds()
                    checks["snapshot"] = "FRESH" if -60 <= age <= ttl else "STALE_OR_CLOCK_SKEW"
    except (ValueError, TypeError, UnicodeError):
        checks["snapshot"] = "INVALID_REPORT"
    except PermissionError:
        checks["snapshot"] = "UNREADABLE"
    except OSError:
        checks["snapshot"] = "UNAVAILABLE"
    # Base timing is a public optional capability on newer Base SHAs, not a deploy requirement.
    timing = root / "opt/base/bin/base-script-timing.py"
    checks["base_timing"] = "OPTIONAL_AVAILABLE" if timing.is_file() else "OPTIONAL_ABSENT"
    legacy = "LEGACY_OR_DRIFT" in checks.values()
    complete = (
        checks["watch_unit"] == "MATCH"
        and checks["telemetry_unit"] == "MATCH"
        and checks["watch_binary"] == "PRESENT"
        and checks["telemetry_binary"] == "PRESENT"
        and checks["snapshot"] == "FRESH"
    )
    classification = "LEGACY_OR_DRIFT" if legacy else "CONTRACT_OK_DISK" if complete else "INCOMPLETE"
    return {"module": "docker", "classification": classification, "checks": checks,
            "runtime_verified": False, "writes": False}


def main() -> int:
    parser = argparse.ArgumentParser(description="Docker Watch installation doctor, read-only")
    parser.add_argument("--root", type=Path, default=Path("/"), help="filesystem root; for fixtures only")
    parser.add_argument("--ttl", type=int, default=180)
    parser.add_argument("--runtime", action="store_true", help="explicit read-only Docker/systemd probes")
    parser.add_argument("--deployment", action="store_true", help="read-only units, executable and permission checks")
    parser.add_argument("--timeout", type=int, default=10, help="per-command timeout, 1..30 seconds")
    args = parser.parse_args()
    if not args.root.is_absolute() or not args.root.is_dir() or not 30 <= args.ttl <= 86400 or not 1 <= args.timeout <= 30:
        parser.error("invalid root, TTL or timeout")
    if args.runtime and args.root.resolve() != Path("/"):
        parser.error("--runtime requires --root=/; fixture roots never inspect the real runtime")
    status = state(args.root, args.ttl, datetime.now(timezone.utc))
    if args.deployment:
        status["deployment"] = deployment_state(args.root)
    if args.runtime:
        status["runtime"] = probe_runtime(args.timeout, os.environ.get("DOCKER_BIN", "docker"))
        status["runtime_verified"] = status["runtime"]["status"] == "PASS"
    print(json.dumps(status, sort_keys=True))
    disk_ok = status["classification"] == "CONTRACT_OK_DISK"
    deployment_ok = not args.deployment or status["deployment"]["status"] == "PASS"
    runtime_ok = not args.runtime or status["runtime_verified"]
    return 0 if disk_ok and deployment_ok and runtime_ok else 1


if __name__ == "__main__":
    sys.exit(main())
