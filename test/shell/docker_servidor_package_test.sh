#!/usr/bin/env bash
# Self-contained offline fixture: no Docker, Telegram or systemd.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
cp "$ROOT/scripts/server/package-servidor.sh" "$TMP/package-script"
mkdir -p "$TMP/repo/scripts/server" "$TMP/repo/config" "$TMP/repo/lib/shell"
cp "$TMP/package-script" "$TMP/repo/scripts/server/package-servidor.sh"
paths=(
  bin/docker-watch
  bin/docker-telemetry
  bin/docker-heartbeat
  lib/render.sh
  lib/shell/collect.sh
  lib/shell/events.sh
  lib/shell/heartbeat.sh
  lib/shell/incident.sh
  lib/shell/persist.sh
  lib/shell/render.sh
  lib/shell/servidor.sh
  libexec/docker-telemetry-runner.py
  libexec/docker-telemetry-collector.py
  config/servidor.env.example
  scripts/server/render-servidor-units.py
)
for path in "${paths[@]}"; do
  mkdir -p -- "$TMP/repo/$(dirname "$path")"
  printf 'fixture: %s\n' "$path" > "$TMP/repo/$path"
done
for path in bin/docker-watch bin/docker-telemetry bin/docker-heartbeat; do chmod +x "$TMP/repo/$path"; done
printf 'private credentials\n' > "$TMP/repo/config/server.env"
printf 'private credentials\n' > "$TMP/repo/lib/shell/unexpected-secret.env"
printf 'private credentials\n' > "$TMP/repo/lib/shell/unreviewed.sh"
(
  cd "$TMP/repo"
  git init -q
  git add -- scripts/server/package-servidor.sh "${paths[@]}" lib/shell/unreviewed.sh
  git -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'fixture'
)
bash "$TMP/repo/scripts/server/package-servidor.sh" >"$TMP/created"
sha="$(git -C "$TMP/repo" rev-parse HEAD)"
archive="$TMP/repo/dist/servidor/docker/$sha/docker-servidor-$sha.tar.gz"
manifest="$TMP/repo/dist/servidor/docker/$sha/docker-servidor-$sha.manifest.json"
test -f "$archive" && test -f "$manifest"
python3 - "$archive" "$manifest" "lucasborges2001/Docker" "$sha" "${paths[@]}" <<'PYTEST'
import hashlib
import json
import pathlib
import sys
import tarfile
archive, manifest, repo, sha, *paths = sys.argv[1:]
metadata = json.loads(pathlib.Path(manifest).read_text())
assert metadata['schema_version'] == 1
assert metadata['owner_repo'] == repo
assert metadata['source_sha'] == sha
assert metadata['archive_sha256'] == hashlib.sha256(pathlib.Path(archive).read_bytes()).hexdigest()
assert metadata['payload_paths'] == paths
with tarfile.open(archive) as tar:
    names = [member.name for member in tar.getmembers() if member.isfile()]
    assert sorted(names) == sorted(paths), (names, paths)
    assert all(member.isfile() or member.isdir() for member in tar.getmembers())
    assert not any('server.env' == pathlib.Path(name).name or 'unreviewed' in name for name in names)
PYTEST
# No accidental overwrite of a previously produced SHA release.
if bash "$TMP/repo/scripts/server/package-servidor.sh" >"$TMP/repeated" 2>&1; then
  echo 'FAIL: immutable release was overwritten' >&2; exit 1
fi
# Altering a tracked source is rejected, even if it would not affect the archive.
printf 'dirty\n' >>"$TMP/repo/scripts/server/package-servidor.sh"
if bash "$TMP/repo/scripts/server/package-servidor.sh" >"$TMP/dirty" 2>&1; then
  echo 'FAIL: dirty checkout accepted' >&2; exit 1
fi
# A tracked symlink under a required path must not be shipped.
git -C "$TMP/repo" checkout -- scripts/server/package-servidor.sh
rm -f "$TMP/repo/${paths[0]}"
ln -s /etc/passwd "$TMP/repo/${paths[0]}"
git -C "$TMP/repo" add -- "${paths[0]}"
git -C "$TMP/repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'symlink-fixture'
if bash "$TMP/repo/scripts/server/package-servidor.sh" >"$TMP/symlink" 2>&1; then
  echo 'FAIL: payload symlink accepted' >&2; exit 1
fi
grep -q 'symlink or nonregular payload rejected' "$TMP/symlink"
echo DOCKER_SERVIDOR_PACKAGE_CONTRACT_PASS
