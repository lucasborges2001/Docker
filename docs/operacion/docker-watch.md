# Operación — Docker Watch y telemetría de contenedores

## Dominio

`Docker` observa exclusivamente el runtime Docker:

- disponibilidad y versión del engine;
- eventos e incidentes Docker;
- recursos de contenedores monitoreados;
- snapshots e historial propios;
- APIs y SuperAdmin read-only.

No recopila CPU, memoria, disco o red general del host. Eso pertenece a `Boot`. Tampoco incorpora señales defensivas de `securityLab` ni wiring del host `Pruebas`.

```text
Docker -> Base
Docker -X-> Boot
Docker -X-> securityLab
```

## Procesos

```text
bin/docker-watch      eventos e incidentes
bin/docker-telemetry  snapshots de recursos
bin/docker-heartbeat  resumen diario y Telegram opcional
```

Ninguno reinicia contenedores.

## Alcance: label o allowlist

La selección para detalle aplica esta unión:

```text
contenedores detallados = MONITOR_LABEL ∪ DOCKER_TELEMETRY_ALLOWLIST
```

Configuración predeterminada:

```env
MONITOR_LABEL=dockwatch.monitor=true
DOCKER_TELEMETRY_INCLUDE_UNLABELED=false
DOCKER_TELEMETRY_ALLOWLIST=
```

Compose:

```yaml
labels:
  dockwatch.monitor: "true"
```

Una allowlist opcional agrega nombres exactos aunque no tengan el label:

```env
DOCKER_TELEMETRY_ALLOWLIST=api,worker
```

`DOCKER_TELEMETRY_INCLUDE_UNLABELED=true` amplía explícitamente el detalle a todos los contenedores, sujeto a `DOCKER_TELEMETRY_MAX_CONTAINERS`. Su valor predeterminado es `false`.

## Configuración

```env
DOCKER_TELEMETRY_ENABLED=true
DOCKER_TELEMETRY_INTERVAL_SECONDS=60
DOCKER_TELEMETRY_INCLUDE_UNLABELED=false
DOCKER_TELEMETRY_ALLOWLIST=
DOCKER_TELEMETRY_HISTORY_RETENTION_DAYS=30
DOCKER_TELEMETRY_HISTORY_MAX_SNAPSHOTS=10000
DOCKER_TELEMETRY_HISTORY_MAX_BYTES=268435456
DOCKER_TELEMETRY_MAX_CONTAINERS=200
DOCKER_TELEMETRY_COMMAND_TIMEOUT_SECONDS=10
DOCKER_WATCH_EVENTS_MAX_BYTES=10485760
DOCKER_WATCH_EVENTS_RETENTION_FILES=5
```

Todos los comandos contra Docker tienen timeout. Un fallo produce `monitoring.errors` y una salida degradada; no dispara comandos correctivos.

## Fuentes

1. Docker CLI con salida JSON estructurada para `ps`, `inspect` y `stats`.
2. `docker stats --no-stream --all` para recursos instantáneos y counters.
3. Fixtures JSON para tests sin daemon real.

cAdvisor queda como integración futura opcional y no es dependencia del core.

## Ejecución

Muestra única desde un checkout:

```bash
BASE_DIR=../Base \
DOCKER_WATCH_REPORTS_DIR="$(mktemp -d)/reports" \
bash bin/docker-telemetry --once --print \
  | python3 -m json.tool >/dev/null
```

Servicio instalado:

```bash
sudo systemctl enable --now docker-watch-telemetry.service
systemctl status docker-watch-telemetry.service --no-pager
```

El servicio no requiere que Docker esté activo para iniciar. Si el daemon no está disponible, persiste un snapshot degradado y continúa intentando en el intervalo configurado.

## Identidad

### `container_ref`

Identificador público sanitizado:

- Compose: `compose:<project>/<service>/<container-number>`;
- sin Compose: `name:<container-name-sanitized>`.

Es estable ante recreate mientras se conserve la identidad Compose o el nombre. No contiene el container ID.

### `instance_ref`

Hash opaco de la instancia:

```text
instance:<16 hex>
```

Cambia al recrear el contenedor. Permite detectar resets de counters sin exponer el ID Docker.

## Snapshot `schema_version=2`

```json
{
  "module": "docker",
  "schema_version": 2,
  "schema_compatibility": {
    "minimum": 1,
    "current": 2,
    "mode": "expand-only"
  }
}
```

Se conservan los campos v1: `module`, `generated_at`, `server`, `status`, `engine`, contadores de `containers`, `monitoring`, `incidents`, `top_restarters`, `telegram` y `artifacts`.

Los consumidores deben aceptar `schema_version >= 1` y leer campos conocidos; no deben exigir igualdad estricta con `1`.

## Semántica de métricas

| Campo | Tipo | Unidad | Fuente | Nullability | Reset |
|---|---|---:|---|---|---|
| `cpu_percent` | gauge | porcentaje | `docker stats` | Sí | No aplica |
| `memory_used_bytes` | gauge | bytes | `docker stats` | Sí | No aplica |
| `memory_limit_bytes` | gauge/config | bytes | `HostConfig.Memory` | Sí, sin límite | Cambio de configuración/recreate |
| `memory_percent` | gauge | porcentaje | stats o cálculo | Sí, sin límite | No aplica |
| `network_rx_bytes_total` | counter | bytes | `docker stats` | Sí | Nueva instancia o engine |
| `network_tx_bytes_total` | counter | bytes | `docker stats` | Sí | Nueva instancia o engine |
| `block_read_bytes_total` | counter | bytes | `docker stats` | Sí | Nueva instancia o engine |
| `block_write_bytes_total` | counter | bytes | `docker stats` | Sí | Nueva instancia o engine |
| `pids` | gauge | procesos | `docker stats` | Sí | No aplica |
| `restart_count` | counter por instancia | reinicios | `docker inspect` | No, default 0 | Recreate |
| `uptime_seconds` | gauge derivado | segundos | `State.StartedAt` | Sí | Start/recreate |

Cada item contiene `sampled_at`. Los agregados pertenecen a la misma muestra.

## Tasas y counter reset

No se persisten tasas como métrica primaria. Para calcular bytes/segundo, dos muestras deben cumplir:

1. mismo `container_ref`;
2. misma `instance_ref`;
3. timestamp posterior;
4. counter actual mayor o igual al anterior.

Si cambia `instance_ref`, disminuye el counter o cambia el engine, las muestras son incompatibles y la tasa debe ser `null`, nunca negativa.

Fixture contractual:

```text
test/fixtures/telemetry_counter_reset.json
```

## Agregados

- CPU total de contenedores monitoreados;
- memoria usada total;
- network RX/TX acumulado;
- block read/write acumulado;
- PIDs totales;
- cantidad sin límite de memoria;
- cantidad sin healthcheck;
- top CPU, memoria, network RX/TX y restarters.

La ausencia de healthcheck es informativa y no cambia por sí sola la severidad.

## Sanitización

Permitido en API/UI:

- `container_ref` e `instance_ref` opaco;
- nombre sanitizado;
- proyecto, servicio y número Compose;
- estado, health, recursos, timestamps y uptime.

Prohibido:

- env vars y secrets;
- mounts;
- labels completas;
- inspect completo;
- container ID completo;
- path del socket Docker;
- logs completos del contenedor.

El snapshot local puede resolver el socket. La normalización API expone solo `socket_resolved`. También elimina el `raw` anidado de `MetricSnapshot` para evitar fugas indirectas.

## Historial y retención

```text
<reports>/latest/report.json
<reports>/latest/summary.txt
<reports>/<YYYYMMDDTHHMMSSZ>/report.json
<reports>/<YYYYMMDDTHHMMSSZ>/summary.txt
```

El pruning solo considera hijos con nombre timestamp dentro de `DOCKER_WATCH_REPORTS_DIR` y aplica:

1. antigüedad;
2. cantidad máxima;
3. tamaño total máximo.

`latest/` no se elimina. Los eventos rotan por tamaño y cantidad en una política separada. Incidentes, eventos y snapshots se correlacionan por timestamp y refs; no se mezclan en un contrato único.

## APIs read-only

Públicas:

```text
public_html/api/health.php
public_html/api/latest.php
public_html/api/history.php
public_html/api/events.php
public_html/api/resources.php
public_html/api/container.php?container_ref=<ref>
```

SuperAdmin:

```text
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
public_html/superadmin/api/resources.php
public_html/superadmin/api/container.php?container_ref=<ref>
```

Invariantes:

- solo `GET`;
- otros métodos: `405` y `Allow: GET`;
- `Cache-Control: no-store`;
- sin comandos recibidos por HTTP;
- sin start, stop, restart, kill, exec o recreate.

## Rootless y Docker Desktop

No se asume `/var/run/docker.sock`. `DOCKER_BIN`, `DOCKER_SOCKET` y el contexto Docker pueden configurarse.

Verificación:

```bash
docker context show
docker version --format '{{.Server.Version}}'
docker stats --no-stream --all --format '{{json .}}'
```

La unidad systemd está orientada a Linux server. En Docker Desktop debe usarse `bash bin/docker-telemetry --once` o un scheduler propio.

## Fixtures

```text
test/fixtures/telemetry_mixed.json
test/fixtures/telemetry_engine_absent.json
test/fixtures/telemetry_counter_reset.json
test/fixtures/snapshot_v1.json
```

Cubren recursos, contenedor sin límite, ausencia de healthcheck, sanitización, engine ausente, unión label/allowlist, counter reset y compatibilidad v1.

## Validación

```bash
find . -type f -name '*.php' -print0 | xargs -0 -n1 php -l
python3 -m py_compile \
  libexec/docker-telemetry-collector.py \
  libexec/docker-telemetry-runner.py
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

Fixture sin daemon:

```bash
python3 libexec/docker-telemetry-runner.py \
  --fixture test/fixtures/telemetry_mixed.json \
  | python3 -m json.tool >/dev/null
```

Búsqueda defensiva:

```bash
grep -RInE 'docker (start|stop|restart|kill|exec)|shell_exec|exec\(|system\(|passthru|proc_open|popen' public_html back test || true
```

## Integración con `Pruebas`

El host debe consumir APIs, `DockerStatusService` o snapshots normalizados. No debe copiar collectors ni leer internals de `libexec/` o `lib/shell/`.

La actualización del gitlink y el smoke `Boot + Docker` pertenecen a una fase separada en `Pruebas`.

## Criterio de operación sana

- watcher, telemetría y heartbeat tienen responsabilidades separadas;
- no existe autorestart;
- detalle limitado por `MONITOR_LABEL ∪ allowlist`;
- snapshot v1 sigue normalizando;
- snapshot v2 expone recursos sanitizados;
- socket y datos sensibles no aparecen en API/UI;
- historial y events están acotados;
- smokes pasan con fixtures sin daemon;
- no hay acciones Docker por HTTP.
