#!/usr/bin/env python3
"""Disposable Docker Watch v2 installation contract checks."""
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

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


    def test_runtime_probes_use_readonly_commands_and_no_shell(self):
        spec = importlib.util.spec_from_file_location("docker_installation_doctor", DOCTOR)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        seen = []
        def fake_run(argv, **kwargs):
            seen.append(argv)
            self.assertIsInstance(argv, list)
            self.assertNotIn("shell", kwargs)
            return subprocess.CompletedProcess(argv, 0, "{}\n", "")
        with mock.patch.object(module.subprocess, "run", side_effect=fake_run):
            result = module.probe_runtime(timeout=2, docker_bin="docker", systemctl_bin="systemctl")
        self.assertEqual("PASS", result["status"])
        self.assertEqual(5, len(seen))
        self.assertEqual(["docker", "stats", "--no-stream", "--all", "--format", "{{json .}}"], seen[2])
        self.assertTrue(all(v == "PASS" for v in result["checks"].values()))

    def test_runtime_probe_classifies_permissions_and_invalid_json(self):
        spec = importlib.util.spec_from_file_location("docker_installation_doctor", DOCTOR)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with mock.patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "permission denied")):
            self.assertEqual("PERMISSION_DENIED", module.command_probe(["docker", "ps"], 2))
        with mock.patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "not-json\n", "")):
            self.assertEqual("INVALID_JSON", module.command_probe(["docker", "ps"], 2, True))

    def test_fixture_root_rejects_live_runtime_probe(self):
        result = subprocess.run([sys.executable, str(DOCTOR), "--root", str(self.root), "--runtime"],
                                capture_output=True, text=True)
        self.assertEqual(2, result.returncode)
        self.assertIn("--runtime requires --root=/", result.stderr)


    def test_deployment_detects_secret_permissions_and_missing_timer(self):
        for rel, line in (
            ("etc/systemd/system/docker-watch-heartbeat.service", "ExecStart=/opt/docker-watch/bin/docker-heartbeat"),
            ("etc/systemd/system/docker-watch-heartbeat.timer", "Unit=docker-watch-heartbeat.service"),
        ):
            (self.root / rel).write_text(line + "\n")
        (self.root / "opt/docker-watch/scripts/server").mkdir(parents=True)
        (self.root / "opt/docker-watch/scripts/server/installation-doctor.py").write_text("doctor\n")
        (self.root / "opt/docker-watch/bin/docker-heartbeat").write_text("bin\n")
        for name in ("docker-watch", "docker-telemetry", "docker-heartbeat"):
            (self.root / "opt/docker-watch/bin" / name).chmod(0o755)
        (self.root / "var/log/docker-watch").mkdir(parents=True)
        env = self.root / "opt/docker-watch/config/server.env"
        env.parent.mkdir(parents=True)
        env.write_text("NO_REAL_SECRET=fixture\n")
        env.chmod(0o600)
        result = subprocess.run([sys.executable, str(DOCTOR), "--root", str(self.root), "--deployment"],
                                capture_output=True, text=True)
        data = json.loads(result.stdout)
        self.assertEqual(0, result.returncode, data)
        self.assertEqual("PASS", data["deployment"]["status"])
        self.assertFalse(data["runtime_verified"])
        env.chmod(0o644)
        failed = subprocess.run([sys.executable, str(DOCTOR), "--root", str(self.root), "--deployment"],
                                capture_output=True, text=True)
        data = json.loads(failed.stdout)
        self.assertEqual(1, failed.returncode)
        self.assertEqual("INSECURE_PERMISSIONS", data["deployment"]["checks"]["server_env"])
        env.chmod(0o600)
        (self.root / "etc/systemd/system/docker-watch-heartbeat.timer").unlink()
        failed = subprocess.run([sys.executable, str(DOCTOR), "--root", str(self.root), "--deployment"],
                                capture_output=True, text=True)
        self.assertEqual("MISSING", json.loads(failed.stdout)["deployment"]["checks"]["unit_timer"])

if __name__ == "__main__":
    unittest.main()
