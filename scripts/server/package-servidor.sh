#!/usr/bin/env bash
# Prepare a SHA-bound servidor artifact from Git objects (never from working-tree secrets).
# This only writes to dist/ in the local checkout; it does not deploy or install.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fail() { printf 'BLOCKED: %s\n' "$*" >&2; exit 2; }
for tool in git gzip sha256sum python3 tar; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing prerequisite: $tool"
done
[[ "$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" == "$ROOT" ]] || fail 'expected a repository-root checkout'
[[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]] || fail 'tracked checkout is dirty'
sha="$(git -C "$ROOT" rev-parse --verify HEAD)"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || fail 'invalid source SHA'
tree="$(git -C "$ROOT" rev-parse 'HEAD^{tree}')"
module="docker"
owner_repo="lucasborges2001/Docker"
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
  entry="$(git -C "$ROOT" ls-tree HEAD -- "$path")"
  read -r mode kind blob actual <<<"$entry"
  [[ "$kind" == blob && "$actual" == "$path" ]] || fail "required tracked file missing: $path"
  [[ "$mode" == 100644 || "$mode" == 100755 ]] || fail "symlink or nonregular payload rejected: $path"
done
out="$ROOT/dist/servidor/$module/$sha"
[[ ! -e "$out" && ! -L "$out" ]] || fail "immutable artifact already exists: $out"
archive="$module-servidor-$sha.tar.gz"
manifest="$module-servidor-$sha.manifest.json"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
# Git archive reads the committed blobs, and explicit exact paths prevent leaks
# from untracked, ignored or unexpected tracked files in source directories.
git -C "$ROOT" archive --format=tar "$sha" "${paths[@]}" | gzip -n >"$tmp/$archive"
actual_count="$(tar -tzf "$tmp/$archive" | grep -v '/$' | wc -l | tr -d ' ')"
[[ "$actual_count" == "${#paths[@]}" ]] || fail 'unexpected payload count in archive'
checksum="$(sha256sum "$tmp/$archive" | cut -d' ' -f1)"
python3 - "$tmp/$manifest" "$owner_repo" "$module" "$sha" "$tree" "$archive" "$checksum" "${paths[@]}" <<'PYMANIFEST'
import json
import pathlib
import sys
out, repo, module, sha, tree, archive, checksum, *paths = sys.argv[1:]
manifest = {
    'schema_version': 1,
    'owner_repo': repo,
    'module': module,
    'source_sha': sha,
    'source_tree_sha': tree,
    'archive_file': archive,
    'archive_sha256': checksum,
    'release_relpath': f'releases/{module}/{sha}',
    'payload_paths': paths,
}
pathlib.Path(out).write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n', encoding='utf-8')
PYMANIFEST
mkdir -p -- "$(dirname "$out")"
mkdir -- "$out" || fail "output directory collision: $out"
mv -- "$tmp/$archive" "$tmp/$manifest" "$out/"
printf 'PACKAGE_SHA=%s\nARCHIVE=%s\nMANIFEST=%s\nSHA256=%s\n' "$sha" "$out/$archive" "$out/$manifest" "$checksum"
