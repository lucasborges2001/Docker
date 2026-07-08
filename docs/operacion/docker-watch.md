# Operación — Docker Watch

## Descripción

Docker Watch observa eventos Docker, genera snapshots periódicos y expone estado read-only para diagnóstico operativo.

La operación se apoya en dos procesos principales:

```txt
bin/docker-watch
bin/docker-heartbeat
```

## Principio operativo

El watcher no reinicia contenedores. Solo observa, registra y alerta.

## Label de monitoreo

Variable:

```env
MONITOR_LABEL=dockwatch.monitor=true
```

En Compose:

```yaml
labels:
  dockwatch.monitor: "true"
```

Solo deben observarse contenedores explícitamente marcados.

## Watcher

Comando:

```bash
bin/docker-watch [--env FILE] [--stdin] [--no-telegram]
```

### Uso esperado

- En producción/server: escuchar `docker events`.
- En tests: usar `--stdin` para inyectar eventos controlados.
- Para pruebas sin Telegram: usar `--no-telegram`.

### Estados relevantes

El watcher abre incidente ante eventos como:

```txt
die
health_status: unhealthy
unhealthy
```

Cierra silenciosamente ante:

```txt
health_status: healthy
healthy
start
```

## Heartbeat

Comando:

```bash
bin/docker-heartbeat [--env FILE] [--reports-dir DIR] [--no-telegram] [--print] [--force]
```

### Uso esperado

- Generar snapshot periódico.
- Persistir `report.json` y `summary.txt`.
- Mantener historial.
- Opcionalmente enviar resumen por Telegram.

### Ejecución local segura

```bash
DOCKER_WATCH_REPORTS_DIR="$(mktemp -d)/reports" \
SEND_TELEGRAM=false \
bin/docker-heartbeat --no-telegram --print --force | python3 -m json.tool >/dev/null
```

## Rutas runtime

| Elemento | Default |
|---|---|
| Reports | `/var/lib/docker-watch/reports` |
| Latest report | `/var/lib/docker-watch/reports/latest/report.json` |
| State | `/var/lib/docker-watch` |
| Events JSONL | `/var/log/docker-watch/events.jsonl` |
| Env server | `/etc/docker-watch/docker-watch.env` |

## APIs read-only

```txt
public_html/api/health.php
public_html/api/latest.php
public_html/api/history.php
public_html/api/events.php
```

SuperAdmin:

```txt
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
```

## Respuesta degradada esperada

Si no existe snapshot real, el módulo puede devolver health degradado con `ok=false`, `severity=unknown` y mensaje de snapshot ausente.

Esto es aceptable para servidor recién instalado o entorno sin heartbeat ejecutado. No debe interpretarse como fallo de PHP si el JSON se genera correctamente.

## Validación local

Desde el submódulo:

```bash
find . -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

Prueba de heartbeat sin Telegram:

```bash
DOCKER_WATCH_REPORTS_DIR="$(mktemp -d)/reports" \
SEND_TELEGRAM=false \
bin/docker-heartbeat --no-telegram --print --force | python3 -m json.tool >/dev/null
```

Prueba del watcher con stdin:

```bash
printf '%s\n' '{"status":"die","Actor":{"Attributes":{"name":"demo","dockwatch.monitor":"true"}}}' \
  | SEND_TELEGRAM=false bin/docker-watch --stdin --no-telegram
```

## Reglas de seguridad

No ejecutar desde SuperAdmin ni endpoints web:

```txt
docker restart
docker stop
docker rm
docker rmi
docker volume rm
docker network rm
docker system prune
docker compose down
```

Cualquier futura acción operativa debe quedar detrás de:

1. confirmación explícita;
2. allowlist acotada;
3. dry-run;
4. logs auditables;
5. smoke de seguridad;
6. documentación separada.

## Troubleshooting

| Síntoma | Causa probable | Revisión |
|---|---|---|
| `Unable to resolve Base` | `BASE_DIR` incorrecto o `Base` no está junto a `Docker`. | `BASE_DIR=../Base bash scripts/dev/smoke.sh`. |
| `No existe snapshot Docker` | Heartbeat no corrió o ruta mal configurada. | Revisar `DOCKER_WATCH_REPORTS_DIR`. |
| Eventos vacíos | No existe `events.jsonl` o no hay contenedores con label. | Revisar `MONITOR_LABEL` y path de events. |
| Telegram falla | Token/chat/env ausente o inválido. | Ejecutar con `SEND_TELEGRAM=false` para aislar runtime. |
| Auditor reporta API warnings | Endpoints actuales son compactos. | Aplicar pendiente `docker-api-contracts`. |

## Criterio de operación sana

- `BASE_DIR=../Base bash scripts/dev/smoke.sh` pasa.
- Heartbeat genera JSON válido con `--no-telegram --print --force`.
- APIs devuelven JSON estable.
- SuperAdmin no expone botones destructivos.
- Logs y reports no se versionan.
