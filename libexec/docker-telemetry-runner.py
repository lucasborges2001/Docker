#!/usr/bin/env python3
"""Run the Docker telemetry collector with label-or-allowlist scope semantics."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import pathlib
import sys
from typing import Any


def load_collector() -> Any:
    path = pathlib.Path(__file__).with_name("docker-telemetry-collector.py")
    spec = importlib.util.spec_from_file_location("docker_telemetry_collector", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("collector module could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def record_key(record: dict[str, Any]) -> str:
    inspect = record.get("inspect") if isinstance(record.get("inspect"), dict) else {}
    ps = record.get("ps") if isinstance(record.get("ps"), dict) else {}
    return str(inspect.get("Id") or ps.get("ID") or record.get("id") or record.get("name") or "")


def merge_sources(primary: dict[str, Any], secondary: dict[str, Any], maximum: int) -> dict[str, Any]:
    merged: list[dict[str, Any]] = []
    seen: set[str] = set()
    for source in (primary, secondary):
        records = source.get("containers") if isinstance(source.get("containers"), list) else []
        for record in records:
            if not isinstance(record, dict):
                continue
            key = record_key(record)
            if key and key in seen:
                continue
            if key:
                seen.add(key)
            merged.append(record)
    errors: list[dict[str, Any]] = []
    for source in (primary, secondary):
        for error in source.get("errors") if isinstance(source.get("errors"), list) else []:
            if isinstance(error, dict) and error not in errors:
                errors.append(error)
    if len(merged) > maximum:
        merged = merged[:maximum]
        errors.append({"code": "max_containers_truncated", "limit": maximum})
    engine = primary.get("engine") if isinstance(primary.get("engine"), dict) else secondary.get("engine")
    return {"engine": engine if isinstance(engine, dict) else {"available": False, "version": None}, "containers": merged, "errors": errors}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", default=os.getenv("DOCKER_TELEMETRY_FIXTURE", ""))
    args = parser.parse_args()
    collector = load_collector()
    sampled_at = collector.utc_now()
    timeout = collector.env_int("DOCKER_TELEMETRY_COMMAND_TIMEOUT_SECONDS", 10, 1, 120)
    maximum = collector.env_int("DOCKER_TELEMETRY_MAX_CONTAINERS", 200, 1, 5000)
    include_unlabeled = collector.env_bool("DOCKER_TELEMETRY_INCLUDE_UNLABELED", False)
    monitor_label = os.getenv("MONITOR_LABEL", "dockwatch.monitor=true").strip()
    allowlist = {item.strip() for item in os.getenv("DOCKER_TELEMETRY_ALLOWLIST", "").split(",") if item.strip()}

    try:
        if args.fixture:
            source = collector.load_fixture(args.fixture)
        elif include_unlabeled or not allowlist:
            source = collector.collect_live(timeout, include_unlabeled, monitor_label, allowlist, maximum)
        else:
            labeled = collector.collect_live(timeout, False, monitor_label, set(), maximum)
            allowed = collector.collect_live(timeout, True, monitor_label, allowlist, maximum)
            source = merge_sources(labeled, allowed, maximum)
        payload = collector.build_payload(source, sampled_at)
    except (OSError, ValueError, json.JSONDecodeError, RuntimeError) as exc:
        payload = collector.build_payload({"engine": {"available": False, "version": None}, "containers": [], "errors": [{"code": "collector_error", "detail": type(exc).__name__}]}, sampled_at)
    json.dump(payload, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
