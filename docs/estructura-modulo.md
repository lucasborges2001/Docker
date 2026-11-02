# Estructura del módulo `Docker`

## Propósito

`Docker` implementa observabilidad operativa para Docker desde servidor y web/SuperAdmin.

Su responsabilidad es leer eventos y snapshots, normalizar estado, persistir evidencia local, enviar alertas opcionales por Telegram y exponer lectura de estado. No debe operar como módulo de remediation automática ni como panel de acciones destructivas.

## Capas principales

| Capa | Ruta | Responsabilidad |
|---|---|---|
| CLI watcher | `bin/docker-watch` | Escucha eventos Docker, filtra por label, registra eventos e incidentes y envía alertas si corresponde. |
| CLI heartbeat | `bin/docker-heartbeat` | Construye snapshot periódico, summary, historial y evento heartbeat. |
| CLI telemetría | `bin/docker-telemetry` | Recopila recursos del engine/containers y genera snapshots v2 con degradación explícita. |
| Shell específico | `lib/shell/` | Lógica Docker: collect, events, incident, render, persist y heartbeat. |
| Bootstrap PHP | `back/bootstrap.php` | Resuelve `Base`, carga dependencias reutilizables y clases propias. |
| Contratos PHP | `back/support/` | Constantes, rutas efectivas y configuración derivada de env. |
| Métricas PHP | `back/metrics/` | Lectura, normalización, historia, eventos y estado para API/UI. |
| Telegram PHP | `back/telegram/` | Formato específico para mensajes Docker. |
| API pública | `public_html/api/` | Endpoints read-only de health, latest, history, events, resources, container y container-trend; guard común GET/405. |
| SuperAdmin | `public_html/superadmin/` | Vista HTML read-only para estado, métricas, eventos, history y contratos. |
| Tests | `test/php`, `test/shell`, `test/python` | Fixtures y pruebas contractuales de telemetría, persistencia, seguridad, instalación e incidentes. |
| Fixtures runtime | `var/sample-reports/` | Reportes de muestra para APIs/UI/tests cuando no existe runtime real. |

## Entrypoints verificados

```txt
bin/docker-watch
bin/docker-heartbeat
bin/docker-telemetry
bin/docker-watch-test
```

Wrappers legacy declarados por README:

```txt
docker-watch.sh
heartbeat.sh
```

## Dependencias con `Base`

`Docker` depende de `Base` para utilidades reutilizables:

```txt
Base/lib/shell/env.sh
Base/lib/shell/log.sh
Base/lib/shell/json.sh
Base/lib/shell/lock.sh
Base/lib/shell/time.sh
Base/lib/shell/telegram.sh
Base/back/bootstrap.php
Base/back/metrics/*
Base/back/telegram/*
```

La resolución se realiza por orden:

1. `BASE_DIR` si está definido;
2. `../Base` junto al submódulo;
3. `/opt/base` en instalación server.

## Configuración efectiva

| Variable | Default | Uso |
|---|---|---|
| `BASE_DIR` | autodetección | Ubicación de `Base`. |
| `DOCKER_WATCH_ENABLED` | `true` | Habilita/deshabilita watcher. |
| `HEARTBEAT_ENABLED` | `true` | Habilita/deshabilita heartbeat. |
| `DOCKER_WATCH_REPORTS_DIR` | `/var/lib/docker-watch/reports` | Directorio de snapshots. |
| `DOCKER_WATCH_STATE_DIR` | `/var/lib/docker-watch` | Estado local y locks. |
| `DOCKER_WATCH_EVENTS_LOG` | `/var/log/docker-watch/events.jsonl` | Log JSONL de eventos. |
| `MONITOR_LABEL` | `dockwatch.monitor=true` | Label de contenedores observados. |
| `SEND_TELEGRAM` | `true` | Envío opcional de Telegram. |

## Modelo de datos esperado

### Snapshot latest

Ruta efectiva:

```txt
${DOCKER_WATCH_REPORTS_DIR}/latest/report.json
```

Shape operativo resumido:

```txt
module
schema_version
generated_at
server
status
engine
containers
monitoring
incidents
top_restarters
telegram
artifacts
base_snapshot
```

### Events JSONL

Ruta efectiva:

```txt
${DOCKER_WATCH_EVENTS_LOG}
```

Cada línea debe ser JSON independiente y legible por `DockerEventReader`.

## Fronteras técnicas

### Permitido

- `docker events` como fuente observacional.
- Persistencia local de snapshots y events JSONL.
- Alertas Telegram por incidente o heartbeat.
- APIs y SuperAdmin read-only.
- Fixtures locales para smoke/demo.

### No permitido por defecto

- Reinicio automático de contenedores.
- Ejecución de comandos Docker desde UI.
- `docker system prune` desde SuperAdmin.
- Borrado de volúmenes/datos por endpoint web.
- Mutación de infraestructura desde endpoints públicos.

## Reconciliación de hallazgos históricos (2026-11-02)

Lectura estática de `Docker/main@494a8b54851105d11b267359cd0de2c27b5197d2`; **no** hubo pruebas HTTP, instalación o revisión completa de estilo en esta pasada.

| Hallazgo anterior | Estado documentado ahora |
|---|---|
| Estructura, contrato y checklist faltantes | Presentes en `docs/`; cualquier aceptación por auditor del host requiere ejecución separada. |
| Falta de guardas HTTP y de `_common.php` | **Implementado en código** (`public_html/api/_common.php` y `public_html/superadmin/support/api.php`); quedan autorización, compatibilidad y smoke HTTP. |
| Uninstall con borrado absoluto sin protección | **Guardas implementadas**: allowlist de rutas, bloqueo de symlinks, dry-run y confirmación diferenciada para purge. Falta verificar install/uninstall/rollback real en VM. |
| SuperAdmin sin documentación local | Existe `public_html/superadmin/dockerFront.md`; faltan aceptación de UI y seguridad integrada. |
| Headers `@file/@brief` y orden de `require_once` en bootstrap | Hallazgos de auditoría histórica **no revalidados** como deuda funcional; comprobar regla aplicable y efecto real antes de abrir trabajo mecánico. |

Consultar [pendientes vivos](pendientes/README.md). No reabrir como deuda un defecto cuya corrección ya está en código, ni declarar cerrado un gate operativo sin ejecutarlo.

## Verificación reproducible

```bash
cd ~/dev/Pruebas
bash scripts/quality/audit_structure.sh submodules/Docker

cd submodules/Docker
find . -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh
```
