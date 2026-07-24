# Docker Watch · Observabilidad Docker

`Docker` es un submódulo operativo para observar el engine, eventos y recursos de contenedores desde servidor y SuperAdmin.

Depende únicamente de `Base` para helpers shell, contratos de métricas y Telegram. Conserva dentro de su propio dominio la recolección Docker, snapshots, historial, events JSONL, incidentes y APIs read-only.

## Entrypoints

```bash
bin/docker-watch
bin/docker-telemetry
bin/docker-heartbeat
bin/docker-watch-test
```

- `docker-watch`: observa eventos y mantiene incidentes; no reinicia contenedores.
- `docker-telemetry`: genera snapshots de recursos una vez o en loop.
- `docker-heartbeat`: genera el resumen diario y Telegram opcional.

Wrappers legacy:

```bash
docker-watch.sh
heartbeat.sh
```

## Alcance de telemetría

Por defecto solo se detalla un contenedor cuando cumple `MONITOR_LABEL`:

```env
MONITOR_LABEL=dockwatch.monitor=true
DOCKER_TELEMETRY_INCLUDE_UNLABELED=false
```

En Compose:

```yaml
labels:
  dockwatch.monitor: "true"
```

Se recopilan CPU, memoria, network I/O, block I/O, PIDs, restart count, health, estado, uptime y metadatos Compose sanitizados. No se exponen env vars, mounts, labels completas, inspect completo ni IDs Docker públicos.

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
python3 libexec/docker-telemetry-collector.py \
  --fixture test/fixtures/telemetry_mixed.json \
  | python3 -m json.tool >/dev/null
```

Documentación operativa: [`docs/operacion/docker-watch.md`](docs/operacion/docker-watch.md).
