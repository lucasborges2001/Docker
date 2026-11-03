#!/usr/bin/env python3
"""Docker storage probe is opt-in and read-only. No Docker daemon required."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest import mock

COLLECTOR = Path(__file__).resolve().parents[2] / "libexec/docker-telemetry-collector.py"


def load_collector():
    spec = importlib.util.spec_from_file_location("docker_telemetry_collector", COLLECTOR)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class DockerStorageCollectorTest(unittest.TestCase):
    def test_size_only_when_enabled(self):
        collector = load_collector()
        calls = []
        container_id = "a" * 64

        def fake_run(argv, timeout):
            calls.append(argv)
            if argv[1] == "version":
                return subprocess.CompletedProcess(argv, 0, "27.5.1\n", "")
            if argv[1] == "ps":
                return subprocess.CompletedProcess(argv, 0, json.dumps({"ID": container_id, "Names": "demo"}) + "\n", "")
            if argv[1] == "inspect":
                inspect = {"Id": container_id, "Name": "/demo", "Config": {"Labels": {}},
                           "State": {"Status": "running"}, "SizeRw": 1024, "SizeRootFs": 8192}
                return subprocess.CompletedProcess(argv, 0, json.dumps([inspect]), "")
            if argv[1] == "stats":
                return subprocess.CompletedProcess(argv, 0, json.dumps({"ID": container_id, "NetIO": "1kB / 2kB"}) + "\n", "")
            raise AssertionError(f"unexpected command: {argv}")

        with mock.patch.object(collector, "run_command", side_effect=fake_run), mock.patch.dict("os.environ", {"DOCKER_BIN": "docker"}):
            enabled = collector.collect_live(2, True, "", set(), 5, True)
            self.assertIn("--size", next(x for x in calls if x[1] == "inspect"))
            values = collector.build_payload(enabled, collector.utc_now())
            self.assertEqual(1024, values["items"][0]["writable_layer_bytes"])
            self.assertEqual(8192, values["items"][0]["rootfs_bytes"])
            self.assertEqual(1024, values["aggregates"]["writable_layer_bytes_total"])
            calls.clear()
            disabled = collector.collect_live(2, True, "", set(), 5, False)
            self.assertNotIn("--size", next(x for x in calls if x[1] == "inspect"))
            self.assertEqual(0, len(disabled["errors"]))


    def test_invalid_or_missing_counters_do_not_become_zero(self):
        collector = load_collector()
        import datetime as dt
        sampled = dt.datetime(2026, 11, 3, 15, tzinfo=dt.timezone.utc)
        record = {
            "ps": {"ID": "demo-id", "Names": "demo"},
            "inspect": {"Id": "demo-id", "Name": "/demo",
                        "State": {"Status": "running",
                                  "StartedAt": (sampled + dt.timedelta(minutes=3)).isoformat()}},
            "stats": {"CPUPerc": "NaN", "MemUsage": "-1B / 1GiB", "PIDs": "-4",
                      "NetIO": "0B / 0B", "BlockIO": "0B / 0B"},
        }
        normalized = collector.normalize_record(record, sampled)
        for field in ("cpu_percent", "memory_used_bytes", "pids",
                      "restart_count", "started_at", "uptime_seconds"):
            self.assertIsNone(normalized[field], field)
        self.assertEqual(normalized["network_rx_bytes_total"], 0)
        self.assertEqual(normalized["block_write_bytes_total"], 0)
        for value in (-1, float("inf"), float("nan"), True, 2**80, "-1B", "9999999999999999999999999B"):
            self.assertIsNone(collector.parse_bytes(value), value)
        self.assertIsNone(collector.parse_percent("inf"))
        self.assertIsNone(collector.parse_percent("-1%"))
        self.assertIsNone(collector.parse_datetime("2026-11-03T15:00:00"))
        self.assertEqual(collector.parse_percent("250.4%"), 250.4)

    def test_observed_zero_and_running_uptime_are_preserved(self):
        collector = load_collector()
        import datetime as dt
        sampled = dt.datetime(2026, 11, 3, 15, tzinfo=dt.timezone.utc)
        record = {
            "ps": {"ID": "demo-id", "Names": "demo"},
            "inspect": {"Id": "demo-id", "Name": "/demo", "RestartCount": 0,
                        "State": {"Status": "running",
                                  "StartedAt": (sampled - dt.timedelta(hours=1)).isoformat()}},
            "stats": {"CPUPerc": "250.4%", "MemUsage": "0B / 1GiB",
                      "PIDs": "0", "NetIO": "0B / 1024B"},
        }
        normalized = collector.normalize_record(record, sampled)
        self.assertEqual(normalized["cpu_percent"], 250.4)
        self.assertEqual(normalized["restart_count"], 0)
        self.assertEqual(normalized["pids"], 0)
        self.assertEqual(normalized["memory_used_bytes"], 0)
        self.assertEqual(normalized["uptime_seconds"], 3600)
        self.assertEqual(normalized["network_rx_bytes_total"], 0)
        self.assertEqual(normalized["network_tx_bytes_total"], 1024)


if __name__ == "__main__":
    unittest.main()
