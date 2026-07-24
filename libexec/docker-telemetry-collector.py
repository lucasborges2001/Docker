#!/usr/bin/env python3
"""Collect sanitized Docker container telemetry using the Docker CLI or fixtures."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
from typing import Any, Iterable

BYTE_UNITS = {
    "b": 1,
    "kb": 1000,
    "kib": 1024,
    "mb": 1000**2,
    "mib": 1024**2,
    "gb": 1000**3,
    "gib": 1024**3,
    "tb": 1000**4,
    "tib": 1024**4,
}
SAFE_REF_RE = re.compile(r"[^a-z0-9_.-]+")


def env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None or value == "":
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int, minimum: int, maximum: int) -> int:
    try:
        value = int(os.getenv(name, str(default)))
    except ValueError:
        value = default
    return max(minimum, min(maximum, value))


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def isoformat(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def parse_datetime(value: Any) -> dt.datetime | None:
    if not isinstance(value, str) or not value or value.startswith("0001-"):
        return None
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = dt.datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def parse_percent(value: Any) -> float | None:
    if value is None:
        return None
    text = str(value).strip().rstrip("%").strip()
    if text in {"", "--"}:
        return None
    try:
        return round(float(text), 4)
    except ValueError:
        return None


def parse_bytes(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return max(0, int(value))
    text = str(value).strip()
    if text in {"", "--"}:
        return None
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)\s*([kmgt]?i?b)?", text, re.IGNORECASE)
    if not match:
        return None
    number = float(match.group(1))
    unit = (match.group(2) or "b").lower()
    multiplier = BYTE_UNITS.get(unit)
    return None if multiplier is None else max(0, int(number * multiplier))


def parse_pair(value: Any) -> tuple[int | None, int | None]:
    if value is None:
        return None, None
    left, separator, right = str(value).partition("/")
    if not separator:
        return parse_bytes(left), None
    return parse_bytes(left), parse_bytes(right)


def safe_component(value: Any, fallback: str = "unknown") -> str:
    text = str(value or "").strip().lower().lstrip("/")
    text = SAFE_REF_RE.sub("-", text).strip("-.")
    return text[:64] or fallback


def instance_ref(container_id: Any) -> str:
    raw = str(container_id or "unknown").encode("utf-8")
    return "instance:" + hashlib.sha256(raw).hexdigest()[:16]


def container_ref(name: Any, labels: dict[str, Any]) -> str:
    project = labels.get("com.docker.compose.project")
    service = labels.get("com.docker.compose.service")
    number = labels.get("com.docker.compose.container-number")
    if project and service:
        suffix = safe_component(number, safe_component(name))
        return f"compose:{safe_component(project)}/{safe_component(service)}/{suffix}"
    return f"name:{safe_component(name)}"


def run_command(args: list[str], timeout: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=False,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=os.environ.copy(),
    )


def load_json_lines(text: str) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            output.append(item)
    return output


def load_fixture(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("fixture root must be an object")
    return data


def collect_live(timeout: int, include_unlabeled: bool, monitor_label: str, allowlist: set[str], max_containers: int) -> dict[str, Any]:
    docker_bin = os.getenv("DOCKER_BIN", "docker")
    errors: list[dict[str, Any]] = []

    try:
        version_result = run_command([docker_bin, "version", "--format", "{{.Server.Version}}"], timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"engine": {"available": False, "version": None}, "containers": [], "errors": [{"code": "engine_unavailable", "detail": type(exc).__name__}]}
    if version_result.returncode != 0:
        return {"engine": {"available": False, "version": None}, "containers": [], "errors": [{"code": "engine_unavailable", "detail": "docker version failed"}]}

    command = [docker_bin, "ps", "-a", "--no-trunc", "--format", "{{json .}}"]
    if not include_unlabeled and monitor_label:
        command.extend(["--filter", f"label={monitor_label}"])
    try:
        ps_result = run_command(command, timeout)
    except subprocess.TimeoutExpired:
        return {"engine": {"available": True, "version": version_result.stdout.strip() or None}, "containers": [], "errors": [{"code": "container_list_timeout"}]}
    if ps_result.returncode != 0:
        return {"engine": {"available": True, "version": version_result.stdout.strip() or None}, "containers": [], "errors": [{"code": "container_list_failed"}]}

    ps_items = load_json_lines(ps_result.stdout)
    selected: list[dict[str, Any]] = []
    for item in ps_items:
        name = str(item.get("Names") or item.get("Name") or "")
        if allowlist and name not in allowlist:
            continue
        selected.append(item)
    truncated = len(selected) > max_containers
    selected = selected[:max_containers]
    ids = [str(item.get("ID") or "") for item in selected if item.get("ID")]
    if not ids:
        return {
            "engine": {"available": True, "version": version_result.stdout.strip() or None},
            "containers": [],
            "errors": ([{"code": "max_containers_truncated"}] if truncated else []),
        }

    try:
        inspect_result = run_command([docker_bin, "inspect", *ids], timeout)
    except subprocess.TimeoutExpired:
        inspect_result = subprocess.CompletedProcess([], 124, "", "")
        errors.append({"code": "inspect_timeout"})
    inspect_items: list[dict[str, Any]] = []
    if inspect_result.returncode == 0:
        try:
            decoded = json.loads(inspect_result.stdout)
            if isinstance(decoded, list):
                inspect_items = [item for item in decoded if isinstance(item, dict)]
        except json.JSONDecodeError:
            errors.append({"code": "inspect_invalid_json"})
    elif not errors:
        errors.append({"code": "inspect_failed"})

    try:
        stats_result = run_command([docker_bin, "stats", "--no-stream", "--all", "--no-trunc", "--format", "{{json .}}", *ids], timeout)
    except subprocess.TimeoutExpired:
        stats_result = subprocess.CompletedProcess([], 124, "", "")
        errors.append({"code": "stats_timeout"})
    stats_items = load_json_lines(stats_result.stdout) if stats_result.returncode == 0 else []
    if stats_result.returncode != 0 and not any(item["code"].startswith("stats_") for item in errors):
        errors.append({"code": "stats_failed"})

    if truncated:
        errors.append({"code": "max_containers_truncated", "limit": max_containers})
    return {
        "engine": {"available": True, "version": version_result.stdout.strip() or None},
        "containers": merge_live_records(selected, inspect_items, stats_items),
        "errors": errors,
    }


def merge_live_records(ps_items: list[dict[str, Any]], inspect_items: list[dict[str, Any]], stats_items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    inspect_by_id = {str(item.get("Id") or ""): item for item in inspect_items}
    stats_by_key: dict[str, dict[str, Any]] = {}
    for stats in stats_items:
        for key in (stats.get("ID"), stats.get("Container"), stats.get("Name")):
            if key:
                stats_by_key[str(key).lstrip("/")] = stats
    records: list[dict[str, Any]] = []
    for ps in ps_items:
        container_id = str(ps.get("ID") or "")
        inspect = inspect_by_id.get(container_id)
        if inspect is None:
            inspect = next((item for key, item in inspect_by_id.items() if key.startswith(container_id)), {})
        name = str((inspect.get("Name") if isinstance(inspect, dict) else None) or ps.get("Names") or "unknown").lstrip("/")
        stats = stats_by_key.get(container_id) or stats_by_key.get(name) or {}
        records.append({"ps": ps, "inspect": inspect, "stats": stats})
    return records


def normalize_record(record: dict[str, Any], sampled_at: dt.datetime) -> dict[str, Any]:
    if "inspect" in record or "stats" in record or "ps" in record:
        inspect = record.get("inspect") if isinstance(record.get("inspect"), dict) else {}
        stats = record.get("stats") if isinstance(record.get("stats"), dict) else {}
        ps = record.get("ps") if isinstance(record.get("ps"), dict) else {}
    else:
        inspect = record
        stats = record.get("stats") if isinstance(record.get("stats"), dict) else {}
        ps = record

    config = inspect.get("Config") if isinstance(inspect.get("Config"), dict) else {}
    labels = config.get("Labels") if isinstance(config.get("Labels"), dict) else {}
    if not labels and isinstance(record.get("labels"), dict):
        labels = record["labels"]
    state_obj = inspect.get("State") if isinstance(inspect.get("State"), dict) else {}
    host_config = inspect.get("HostConfig") if isinstance(inspect.get("HostConfig"), dict) else {}

    name = str(inspect.get("Name") or record.get("name") or ps.get("Names") or "unknown").lstrip("/")
    cid = inspect.get("Id") or record.get("id") or ps.get("ID") or name
    state = str(state_obj.get("Status") or record.get("state") or ps.get("State") or "unknown")
    health_obj = state_obj.get("Health") if isinstance(state_obj.get("Health"), dict) else {}
    health = health_obj.get("Status") or record.get("health")
    health_value = str(health) if health not in (None, "") else None
    has_healthcheck = isinstance(config.get("Healthcheck"), dict) or health_value is not None
    started = parse_datetime(state_obj.get("StartedAt") or record.get("started_at"))
    uptime_seconds = None
    if started is not None and state == "running":
        uptime_seconds = max(0, int((sampled_at - started).total_seconds()))

    memory_used, _ = parse_pair(stats.get("MemUsage") if "MemUsage" in stats else stats.get("memory_usage"))
    configured_limit = parse_bytes(host_config.get("Memory") if "Memory" in host_config else record.get("memory_limit_bytes"))
    memory_limit = configured_limit if configured_limit and configured_limit > 0 else None
    if memory_used is None:
        memory_used = parse_bytes(stats.get("memory_used_bytes"))
    if memory_limit is None and record.get("memory_limit_bytes") not in (None, 0, "0"):
        memory_limit = parse_bytes(record.get("memory_limit_bytes"))
    memory_percent = parse_percent(stats.get("MemPerc") if "MemPerc" in stats else stats.get("memory_percent"))
    if memory_percent is None and memory_used is not None and memory_limit:
        memory_percent = round((memory_used / memory_limit) * 100, 4)

    network_rx, network_tx = parse_pair(stats.get("NetIO") if "NetIO" in stats else stats.get("network_io"))
    block_read, block_write = parse_pair(stats.get("BlockIO") if "BlockIO" in stats else stats.get("block_io"))
    network_rx = network_rx if network_rx is not None else parse_bytes(stats.get("network_rx_bytes_total"))
    network_tx = network_tx if network_tx is not None else parse_bytes(stats.get("network_tx_bytes_total"))
    block_read = block_read if block_read is not None else parse_bytes(stats.get("block_read_bytes_total"))
    block_write = block_write if block_write is not None else parse_bytes(stats.get("block_write_bytes_total"))

    pids_raw = stats.get("PIDs") if "PIDs" in stats else stats.get("pids")
    try:
        pids = None if pids_raw in (None, "", "--") else max(0, int(pids_raw))
    except (TypeError, ValueError):
        pids = None

    restart_raw = inspect.get("RestartCount") if "RestartCount" in inspect else record.get("restart_count", 0)
    try:
        restart_count = max(0, int(restart_raw or 0))
    except (TypeError, ValueError):
        restart_count = 0

    project = labels.get("com.docker.compose.project")
    service = labels.get("com.docker.compose.service")
    number = labels.get("com.docker.compose.container-number")
    return {
        "container_ref": container_ref(name, labels),
        "instance_ref": instance_ref(cid),
        "name": safe_component(name),
        "compose": {
            "project": safe_component(project) if project else None,
            "service": safe_component(service) if service else None,
            "container_number": safe_component(number) if number else None,
        },
        "state": state,
        "health": health_value,
        "has_healthcheck": has_healthcheck,
        "status": str(record.get("status") or ps.get("Status") or state),
        "cpu_percent": parse_percent(stats.get("CPUPerc") if "CPUPerc" in stats else stats.get("cpu_percent")),
        "memory_used_bytes": memory_used,
        "memory_limit_bytes": memory_limit,
        "memory_percent": memory_percent,
        "network_rx_bytes_total": network_rx,
        "network_tx_bytes_total": network_tx,
        "block_read_bytes_total": block_read,
        "block_write_bytes_total": block_write,
        "pids": pids,
        "restart_count": restart_count,
        "started_at": isoformat(started) if started else None,
        "uptime_seconds": uptime_seconds,
        "sampled_at": isoformat(sampled_at),
    }


def top(items: Iterable[dict[str, Any]], field: str, limit: int = 5) -> list[dict[str, Any]]:
    ranked = sorted(
        (item for item in items if isinstance(item.get(field), (int, float))),
        key=lambda item: float(item[field]),
        reverse=True,
    )
    return [
        {"container_ref": item["container_ref"], "name": item["name"], field: item[field]}
        for item in ranked[:limit]
    ]


def aggregate(items: list[dict[str, Any]]) -> dict[str, Any]:
    sum_field = lambda field: sum(int(item.get(field) or 0) for item in items)
    cpu_total = round(sum(float(item.get("cpu_percent") or 0.0) for item in items), 4)
    return {
        "cpu_percent": cpu_total,
        "memory_used_bytes": sum_field("memory_used_bytes"),
        "network_rx_bytes_total": sum_field("network_rx_bytes_total"),
        "network_tx_bytes_total": sum_field("network_tx_bytes_total"),
        "block_read_bytes_total": sum_field("block_read_bytes_total"),
        "block_write_bytes_total": sum_field("block_write_bytes_total"),
        "pids": sum_field("pids"),
        "without_memory_limit": sum(1 for item in items if item.get("memory_limit_bytes") is None),
        "without_healthcheck": sum(1 for item in items if not item.get("has_healthcheck")),
        "top_cpu": top(items, "cpu_percent"),
        "top_memory": top(items, "memory_used_bytes"),
        "top_network_rx": top(items, "network_rx_bytes_total"),
        "top_network_tx": top(items, "network_tx_bytes_total"),
        "top_restarters": top(items, "restart_count"),
    }


def build_payload(source: dict[str, Any], sampled_at: dt.datetime) -> dict[str, Any]:
    raw_records = source.get("containers") if isinstance(source.get("containers"), list) else []
    items = [normalize_record(record, sampled_at) for record in raw_records if isinstance(record, dict)]
    items.sort(key=lambda item: item["container_ref"])
    return {
        "sampled_at": isoformat(sampled_at),
        "engine": source.get("engine") if isinstance(source.get("engine"), dict) else {"available": False, "version": None},
        "items": items,
        "aggregates": aggregate(items),
        "errors": source.get("errors") if isinstance(source.get("errors"), list) else [],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", default=os.getenv("DOCKER_TELEMETRY_FIXTURE", ""))
    args = parser.parse_args()

    sampled_at = utc_now()
    timeout = env_int("DOCKER_TELEMETRY_COMMAND_TIMEOUT_SECONDS", 10, 1, 120)
    max_containers = env_int("DOCKER_TELEMETRY_MAX_CONTAINERS", 200, 1, 5000)
    include_unlabeled = env_bool("DOCKER_TELEMETRY_INCLUDE_UNLABELED", False)
    monitor_label = os.getenv("MONITOR_LABEL", "dockwatch.monitor=true").strip()
    allowlist = {item.strip() for item in os.getenv("DOCKER_TELEMETRY_ALLOWLIST", "").split(",") if item.strip()}

    try:
        source = load_fixture(args.fixture) if args.fixture else collect_live(timeout, include_unlabeled, monitor_label, allowlist, max_containers)
        payload = build_payload(source, sampled_at)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        payload = build_payload({"engine": {"available": False, "version": None}, "containers": [], "errors": [{"code": "collector_error", "detail": type(exc).__name__}]}, sampled_at)
    json.dump(payload, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
