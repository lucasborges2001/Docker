#!/usr/bin/env python3
"""Read-only on-disk diagnosis of Docker Watch telemetry vs legacy watcher."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys

SERVICE = "etc/systemd/system/docker-watch.service"
TELEMETRY = "etc/systemd/system/docker-watch-telemetry.service"
BIN_WATCH = "opt/docker-watch/bin/docker-watch"
BIN_TELEMETRY = "opt/docker-watch/bin/docker-telemetry"
REPORT = "var/lib/docker-watch/reports/latest/report.json"
MAX_SIZE = 2097152


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
    args = parser.parse_args()
    if not args.root.is_absolute() or not args.root.is_dir() or not 30 <= args.ttl <= 86400:
        parser.error("invalid root or TTL")
    status = state(args.root, args.ttl, datetime.now(timezone.utc))
    print(json.dumps(status, sort_keys=True))
    return 0 if status["classification"] == "CONTRACT_OK_DISK" else 1


if __name__ == "__main__":
    sys.exit(main())
