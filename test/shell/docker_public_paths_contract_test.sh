#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
grep -Fq "'base_snapshot'=>array_replace" "$ROOT/back/metrics/DockerSnapshotNormalizer.php"
grep -Fq "'artifacts'=>[]," "$ROOT/back/metrics/DockerSnapshotNormalizer.php"
if grep -Fq "'latest_path'" "$ROOT/back/metrics/DockerStatusService.php"; then
  echo 'FAIL: health exposes latest path' >&2; exit 1
fi
if grep -Fq "'events_path'" "$ROOT/back/metrics/DockerStatusService.php"; then
  echo 'FAIL: health exposes events path' >&2; exit 1
fi
if grep -Fq "\$data['path']" "$ROOT/back/metrics/DockerHistoryService.php"; then
  echo 'FAIL: history exposes report file path' >&2; exit 1
fi
if grep -Fq "'paths'=>docker_config()" "$ROOT/public_html/superadmin/api/probe.php"; then
  echo 'FAIL: probe exposes runtime paths' >&2; exit 1
fi
if grep -Fq 'dockerPaths[' "$ROOT/public_html/superadmin/partials/contracts.php"; then
  echo 'FAIL: SuperAdmin displays runtime paths' >&2; exit 1
fi
echo 'DOCKER_PUBLIC_PATHS_STATIC_PASS (HTTP integration not executed)'
