# Operación — Docker Watch y telemetría de contenedores

## Dominio

`Docker` observa exclusivamente el runtime Docker:

- disponibilidad y versión del engine;
- eventos e incidentes Docker;
- recursos de contenedores monitoreados;
- snapshots e historial propios;
- APIs y SuperAdmin read-only.

No recopila CPU, memoria, disco o red general del host. Eso pertenece a `Boot`. Tampoco incorpora señales defensivas de `securityLab` ni wiring del host `Pruebas`.

## Dependencias

```text
Docker -> Base
Docker -X-> Boot
Docker -X-> securityLab
```

`Base` aporta helpers reutilizables de env, log, JSON, lock, tiempo, métricas y Telegram. La lógica Docker permanece en este repositorio.

## Procesos

```text
bin/docker-watch      eventos e incidentes
bin/docker-telemetry  snapshots de recursos
bin/docker-heartbeat  resumen diario y Telegram opcional
```

El watcher y la telemetría nunca reinician contenedores.

## Label y allowlist

Alcance predeterminado:

```env
MONITOR_LABEL=dockwatch.monitor=true
DOCKER_TELEMETRY_INCLUDE_UNLABELED=false
```

Compose:

```yaml
labels:
  dockwatch.monitor: "true"
```

También puede aplicarse una allowlist adicional por nombre exacto:

```env
DOCKER_TELEMETRY_ALLOWLIST=api,worker
```

La allowlist restringe; no amplía el resultado del filtro por label salvo que `DOCKER_TELEMETRY_INCLUDE_UNLABELED=true` se habilite explícitamente.

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

## Recolección

Orden efectivo del baseline:

1. Docker CLI con salida JSON estructurada para `ps`, `inspect` y `stats`;
2. `docker stats --no-stream --all` para recursos instantáneos y counters;
3. fixtures JSON para tests sin daemon real.

cAdvisor queda como integración futura opcional. No es dependencia del core.

### Ejecución única

```bash
BASE_DIR=../Base \
DOCKER_WATCH_REPORTS_DIR="$(mktemp -d)/reports" \
bin/docker-telemetry --once --print \
  | python3 -m json.tool >/dev/null
```

### Servicio periódico

```bash
sudo systemctl enable --now docker-watch-telemetry.service
systemctl status docker-watch-telemetry.service --no-pager
```

El proceso respeta `DOCKER_TELEMETRY_INTERVAL_SECONDS`, con mínimo de cinco segundos.

## Contrato de identidad

### `container_ref`

Identificador público sanitizado:

- Compose: `compose:<project>/<service>/<container-number>`;
- sin Compose: `name:<container-name-sanitized>`.

Estabilidad:

- es estable ante recreate cuando proyecto, servicio y número Compose se conservan;
- cambia si cambia el nombre o la identidad Compose;
- no contiene el container ID completo.

### `instance_ref`

Hash opaco de la instancia Docker:

```text
instance:<16 hex>
```

Cambia cuando el contenedor es recreado. Permite determinar si dos counters pertenecen a la misma instancia sin exponer el ID Docker.

## Snapshot `schema_version=2`

La evolución es expand-only:

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

Los campos v1 se conservan: `module`, `generated_at`, `server`, `status`, `engine`, contadores de `containers`, `monitoring`, `incidents`, `top_restarters`, `telegram` y `artifacts`.

Los consumidores v1 deben aceptar `schema_version >= 1` y no exigir igualdad estricta con `1`.

## Semántica de métricas

| Campo | Tipo | Unidad | Fuente | Null | Reinicio |
|---|---|---:|---|---|---|
| `cpu_percent` | gauge | porcentaje | `docker stats` | Sí si stats no responde | No aplica |
| `memory_used_bytes` | gauge | bytes | `docker stats` | Sí | No aplica |
| `memory_limit_bytes` | gauge/config | bytes | `HostConfig.Memory` | Sí: sin límite explícito | Cambia con configuración/recreate |
| `memory_percent` | gauge | porcentaje | stats o cálculo used/limit | Sí sin límite | No aplica |
| `network_rx_bytes_total` | counter | bytes | `docker stats` | Sí | Se reinicia con nueva `instance_ref` o engine/runtime |
| `network_tx_bytes_total` | counter | bytes | `docker stats` | Sí | Se reinicia con nueva `instance_ref` o engine/runtime |
| `block_read_bytes_total` | counter | bytes | `docker stats` | Sí | Se reinicia con nueva `instance_ref` o engine/runtime |
| `block_write_bytes_total` | counter | bytes | `docker stats` | Sí | Se reinicia con nueva `instance_ref` o engine/runtime |
| `pids` | gauge | procesos | `docker stats` | Sí | No aplica |
| `restart_count` | counter por instancia | reinicios | `docker inspect` | No, default 0 | Se reinicia al recrear el contenedor |
| `uptime_seconds` | gauge derivado | segundos | `State.StartedAt` | Sí si no está running | Se reinicia al iniciar/recrear |

Cada item incluye `sampled_at`. Los agregados usan la misma muestra.

### Tasas

No se almacenan tasas como dato primario en esta fase. Para calcular bytes/segundo:

1. ambas muestras deben tener el mismo `container_ref`;
2. ambas deben tener la misma `instance_ref`;
3. el segundo counter debe ser mayor o igual al primero;
4. los timestamps deben ser válidos y crecientes.

Si cambia `instance_ref`, el counter disminuye o el engine se reinicia, la comparación es incompatible y la tasa debe ser `null`, no negativa.

## Agregados

El snapshot incluye:

- CPU sumada de contenedores monitoreados;
- memoria usada total;
- network RX/TX acumulado;
- block read/write acumulado;
- PIDs totales;
- cantidad sin límite de memoria;
- cantidad sin healthcheck;
- top CPU, memoria, network RX/TX y restarters.

La ausencia de healthcheck es informativa. No cambia por sí sola `status.severity`.

## Datos sanitizados

Permitidos en API/UI:

- `container_ref` e `instance_ref` opaco;
- nombre sanitizado;
- proyecto, servicio y número Compose;
- estado, health y recursos;
- timestamps y uptime.

No permitidos:

- env vars;
- secrets;
- mounts;
- labels completas;
- inspect completo;
- container ID completo;
- socket Docker;
- logs completos del contenedor.

El snapshot local puede resolver el path del socket para operar. `DockerSnapshotNormalizer` elimina el path en API y expone únicamente `socket_resolved`.

## Historial y retención

```text
<reports>/latest/report.json
<reports>/latest/summary.txt
<reports>/<YYYYMMDDTHHMMSSZ>/report.json
<reports>/<YYYYMMDDTHHMMSSZ>/summary.txt
```

El pruning solo considera directorios hijos con nombre timestamp dentro de `DOCKER_WATCH_REPORTS_DIR`. Aplica, en orden:

1. antigüedad;
2. cantidad máxima;
3. tamaño total máximo.

`latest/` no se elimina.

Los eventos siguen en JSONL y rotan por tamaño con retención independiente. Snapshots, eventos e incidentes no se mezclan; se correlacionan por timestamp, `container_ref` e `instance_ref`.

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

Reglas:

- solo `GET`;
- otros métodos devuelven `405` y `Allow: GET`;
- `Cache-Control: no-store`;
- sin comandos recibidos por HTTP;
- sin acciones start/stop/restart/kill/exec/recreate.

## Docker rootless y Docker Desktop

No se asume que `/var/run/docker.sock` exista. `DOCKER_BIN` y `DOCKER_SOCKET` pueden configurarse, pero el collector usa la CLI y el contexto Docker efectivo.

En rootless o Docker Desktop deben verificarse:

```bash
docker context show
docker version --format '{{.Server.Version}}'
docker stats --no-stream --all --format '{{json .}}'
```

La instalación systemd incluida está orientada a Linux server. Docker Desktop debe ejecutar `bin/docker-telemetry --once` o un scheduler propio; no se instala systemd automáticamente allí.

## Fixtures

```text
test/fixtures/telemetry_mixed.json
test/fixtures/telemetry_engine_absent.json
test/fixtures/snapshot_v1.json
```

Cubren:

- recursos y agregados;
- contenedor sin límite;
- contenedor sin healthcheck;
- sanitización de labels e IDs;
- engine ausente;
- compatibilidad de snapshot v1.

Un counter reset se detecta en integración comparando `instance_ref`; no se interpreta como tasa negativa.

## Validación

```bash
find . -type f -name '*.php' -print0 | xargs -0 -n1 php -l
python3 -m py_compile libexec/docker-telemetry-collector.py
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

Collector sin daemon:

```bash
python3 libexec/docker-telemetry-collector.py \
  --fixture test/fixtures/telemetry_mixed.json \
  | python3 -m json.tool >/dev/null
```

Búsqueda defensiva:

```bash
grep -RInE 'docker (start|stop|restart|kill|exec)|shell_exec|exec\(|system\(|passthru|proc_open|popen' public_html back test || true
```

## Integración con `Pruebas`

El host debe consumir únicamente APIs, `DockerStatusService` o snapshots normalizados. No debe copiar collectors ni leer internals de `libexec/` o `lib/shell/`.

La actualización del gitlink y los smokes `Boot + Docker` pertenecen a una fase separada en `Pruebas`.

## Criterio de operación sana

- watcher, telemetría y heartbeat tienen responsabilidades separadas;
- no existe autorestart;
- el detalle está limitado por label/allowlist;
- `schema_version=1` sigue normalizando;
- el socket y datos sensibles no aparecen en API/UI;
- el historial está acotado;
- los smokes pasan con fixtures sin daemon;
- las acciones Docker no están expuestas por HTTP.
