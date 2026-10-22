#!/usr/bin/env python3
"""Disposable Docker Watch v2 installation contract checks."""
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

DOCTOR = Path(__file__).resolve().parents[2] / "scripts/server/installation-doctor.py"


class DockerInstallDoctorTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="docker-doctor-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for part in ("etc/systemd/system", "opt/docker-watch/bin", "var/lib/docker-watch/reports/latest"):
            (self.root / part).mkdir(parents=True)
        (self.root / "etc/systemd/system/docker-watch.service").write_text("ExecStart=/opt/docker-watch/bin/docker-watch\n")
        (self.root / "etc/systemd/system/docker-watch-telemetry.service").write_text("ExecStart=/opt/docker-watch/bin/docker-telemetry --loop\n")
        for name in ("docker-watch", "docker-telemetry"):
            (self.root / "opt/docker-watch/bin" / name).write_text("bin")
        self.report = self.root / "var/lib/docker-watch/reports/latest/report.json"
        self.make_report()

    def make_report(self, delay=30):
        self.report.write_text(json.dumps({"module": "docker", "schema_version": 2,
            "generated_at": (datetime.now(timezone.utc) - timedelta(seconds=delay)).strftime("%Y-%m-%dT%H:%M:%SZ")}))

    def execute(self):
        result = subprocess.run([sys.executable, str(DOCTOR), "--root", str(self.root)], capture_output=True, text=True)
        return result.returncode, json.loads(result.stdout)

    def test_fresh_candidate_not_runtime_proof(self):
        code, data = self.execute()
        self.assertEqual(0, code)
        self.assertEqual("CONTRACT_OK_DISK", data["classification"])
        self.assertFalse(data["runtime_verified"])

    def test_old_watcher_unit(self):
        (self.root / "etc/systemd/system/docker-watch.service").write_text("ExecStart=/opt/docker-watch/docker-watch.sh\n")
        self.assertEqual("LEGACY_OR_DRIFT", self.execute()[1]["classification"])

    def test_missing_telemetry_unit(self):
        (self.root / "etc/systemd/system/docker-watch-telemetry.service").unlink()
        self.assertEqual("MISSING", self.execute()[1]["checks"]["telemetry_unit"])
        self.assertEqual(1, self.execute()[0])

    def test_stale_snapshot_is_unknown(self):
        self.make_report(delay=2000)
        self.assertEqual("STALE_OR_CLOCK_SKEW", self.execute()[1]["checks"]["snapshot"])
        self.assertEqual("INCOMPLETE", self.execute()[1]["classification"])

    def test_wrong_module(self):
        self.report.write_text(json.dumps({"module": "boot", "schema_version": 2}))
        self.assertEqual("INVALID_CONTRACT", self.execute()[1]["checks"]["snapshot"])


if __name__ == "__main__":
    unittest.main()
