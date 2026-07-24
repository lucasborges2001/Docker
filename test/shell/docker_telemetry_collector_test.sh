#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$DIR/libexec/docker-telemetry-collector.py"
FIXTURES="$DIR/test/fixtures"

mixed="$(python3 "$COLLECTOR" --fixture "$FIXTURES/telemetry_mixed.json")"
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

absent="$(python3 "$COLLECTOR" --fixture "$FIXTURES/telemetry_engine_absent.json")"
ABSENT="$absent" python3 - <<'PY'
import json, os
payload=json.loads(os.environ['ABSENT'])
assert payload['engine']['available'] is False
assert payload['items']==[]
assert payload['errors'][0]['code']=='engine_unavailable'
PY

echo "docker_telemetry_collector_test OK"
