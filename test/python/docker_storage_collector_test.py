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


if __name__ == "__main__":
    unittest.main()
