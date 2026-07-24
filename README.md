# Docker Watch · Observabilidad Docker

`Docker` es un submódulo operativo para observar el engine, eventos y recursos de contenedores desde servidor y SuperAdmin.

Depende únicamente de `Base` para helpers shell, contratos de métricas y Telegram. Conserva dentro de su dominio la recolección Docker, snapshots, historial, events JSONL, incidentes y APIs read-only.

## Entrypoints

```bash
bash bin/docker-watch
bash bin/docker-telemetry
bash bin/docker-heartbeat
bash bin/docker-watch-test
```

- `docker-watch`: observa eventos y mantiene incidentes; no reinicia contenedores.
- `docker-telemetry`: genera snapshots de recursos una vez o en loop.
- `docker-heartbeat`: genera el resumen diario y Telegram opcional.

Después de `scripts/server/install.sh`, los entrypoints quedan instalados con permiso ejecutable bajo `/opt/docker-watch/bin`.

## Alcance de telemetría

Por defecto solo se detallan contenedores con `MONITOR_LABEL`. La allowlist opcional amplía el alcance por nombre exacto:

```text
contenedores detallados = MONITOR_LABEL ∪ DOCKER_TELEMETRY_ALLOWLIST
```

```env
MONITOR_LABEL=dockwatch.monitor=true
DOCKER_TELEMETRY_INCLUDE_UNLABELED=false
DOCKER_TELEMETRY_ALLOWLIST=
```

En Compose:

```yaml
labels:
  dockwatch.monitor: "true"
```

Se recopilan CPU, memoria, network I/O, block I/O, PIDs, restart count, health, estado, uptime y metadatos Compose sanitizados. No se exponen env vars, mounts, labels completas, inspect completo, socket ni IDs Docker públicos.

## No autorestart

El módulo observa, registra, resume y alerta. No ejecuta `start`, `stop`, `restart`, `kill`, `exec` ni `recreate` desde web.

## Snapshot

El contrato actual usa `schema_version=2` en modo expand-only y conserva los campos v1. Los consumidores deben aceptar `schema_version >= 1` y leer solo campos documentados.

## Tests

```bash
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

Prueba sin daemon real:

```bash
python3 libexec/docker-telemetry-runner.py \
  --fixture test/fixtures/telemetry_mixed.json \
  | python3 -m json.tool >/dev/null
```

Documentación operativa: [`docs/operacion/docker-watch.md`](docs/operacion/docker-watch.md).
