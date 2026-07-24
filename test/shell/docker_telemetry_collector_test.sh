#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$DIR/libexec/docker-telemetry-collector.py"
RUNNER="$DIR/libexec/docker-telemetry-runner.py"
FIXTURES="$DIR/test/fixtures"

python3 -m py_compile "$COLLECTOR" "$RUNNER"

mixed="$(python3 "$RUNNER" --fixture "$FIXTURES/telemetry_mixed.json")"
MIXED="$mixed" python3 - <<'PY'
import json, os
payload=json.loads(os.environ['MIXED'])
assert payload['engine']['available'] is True
assert len(payload['items']) == 2
api=next(item for item in payload['items'] if item['name']=='demo-api-1')
assert api['container_ref']=='compose:demo/api/1'
assert api['instance_ref'].startswith('instance:')
assert api['memory_limit_bytes']==536870912
assert payload['aggregates']['cpu_percent']==15.75
assert payload['aggregates']['without_memory_limit']==1
assert payload['aggregates']['without_healthcheck']==1
serialized=json.dumps(payload)
assert 'secret.label' not in serialized
assert 'aaaaaaaaaaaaaaaa' not in serialized
PY

absent="$(python3 "$RUNNER" --fixture "$FIXTURES/telemetry_engine_absent.json")"
ABSENT="$absent" python3 - <<'PY'
import json, os
payload=json.loads(os.environ['ABSENT'])
assert payload['engine']['available'] is False
assert payload['items']==[]
assert payload['errors'][0]['code']=='engine_unavailable'
PY

ROOT="$DIR" python3 - <<'PY'
import importlib.util, os, pathlib
path=pathlib.Path(os.environ['ROOT'])/'libexec/docker-telemetry-runner.py'
spec=importlib.util.spec_from_file_location('docker_telemetry_runner',path)
assert spec is not None and spec.loader is not None
runner=importlib.util.module_from_spec(spec); spec.loader.exec_module(runner)
labelled={'engine':{'available':True},'containers':[{'ps':{'ID':'a','Names':'labelled'}}],'errors':[]}
allowed={'engine':{'available':True},'containers':[{'ps':{'ID':'a','Names':'labelled'}},{'ps':{'ID':'b','Names':'allowlisted'}}],'errors':[]}
merged=runner.merge_sources(labelled,allowed,200)
assert [item['ps']['Names'] for item in merged['containers']]==['labelled','allowlisted']
PY

FIXTURE="$FIXTURES/telemetry_counter_reset.json" python3 - <<'PY'
import json, os
with open(os.environ['FIXTURE'],encoding='utf-8') as handle: fixture=json.load(handle)
previous=fixture['previous']; current=fixture['current']; expected=fixture['expected']
compatible=(previous['container_ref']==current['container_ref'] and previous['instance_ref']==current['instance_ref'] and current['value']>=previous['value'])
rate=None if not compatible else current['value']-previous['value']
assert compatible is expected['compatible'] is False
assert rate is expected['rate_bytes_per_second'] is None
assert expected['reason']=='instance_changed'
PY

echo "docker_telemetry_collector_test OK"
