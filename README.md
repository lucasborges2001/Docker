# Docker Watch · Observabilidad Docker

`Docker` es un submódulo operativo para observar Docker desde servidor y web/SuperAdmin.

Esta versión reemplaza el watcher aislado por una arquitectura dependiente de `Base`:

- `Base/lib/shell/*`: env, log, json, lock, time y Telegram reutilizable.
- `Base/back/metrics/*`: contratos y lectura base de snapshots.
- `Base/back/telegram/*`: escape/parseo/cliente Telegram reutilizable.

`Docker` conserva solo lógica específica: `docker events`, gate por label, anti-spam por incidente, heartbeat, snapshots, events JSONL, APIs read-only y vista SuperAdmin.

## Entrypoints

```bash
bin/docker-watch
bin/docker-heartbeat
bin/docker-watch-test
```

Wrappers legacy:

```bash
docker-watch.sh
heartbeat.sh
```

## No autorestart

El watcher no reinicia contenedores. Solo observa, registra y alerta.

## MONITOR_LABEL

```env
MONITOR_LABEL=dockwatch.monitor=true
```

En Compose:

```yaml
labels:
  dockwatch.monitor: "true"
```

## Tests

```bash
BASE_DIR=../Base bash scripts/dev/smoke.sh
```
