# Auditoría — Docker Watch — 2026-07-08

## Target auditado

```txt
Host: lucasborges2001/Pruebas
Submódulo: submodules/Docker
Repositorio del submódulo: lucasborges2001/Docker
```

## Estado de ejecución

Revisión remota por conector GitHub y evidencia pegada del auditor local.

No se ejecutaron comandos dentro del checkout real del usuario. No se hicieron commits, push, PR, merges ni cambios remotos.

## Evidencia revisada

### Host `Pruebas`

```txt
.gitmodules
config/submodules.php
docs/pendientes/README.md
docs/auditorias/README.md
docs/cambios/README.md
```

### Submódulo `Docker`

```txt
README.md
.gitignore
bin/docker-watch
bin/docker-heartbeat
back/bootstrap.php
back/support/contracts.php
back/support/paths.php
back/support/config.php
back/metrics/DockerStatusService.php
back/metrics/DockerSnapshotReader.php
back/metrics/DockerSnapshotNormalizer.php
back/metrics/DockerEventReader.php
back/metrics/DockerHistoryService.php
public_html/api/health.php
public_html/api/latest.php
public_html/api/history.php
public_html/api/events.php
public_html/superadmin/index.php
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
public_html/superadmin/support/api.php
public_html/superadmin/assets/docker-superadmin.js
scripts/dev/smoke.sh
scripts/server/uninstall.sh
test/php/DockerStatusServiceTest.php
test/php/DockerSnapshotNormalizerTest.php
test/shell/docker_heartbeat_test.sh
```

## Mapa del módulo

| Capa | Estado verificado | Riesgo |
|---|---|---|
| Host `Pruebas` | Declara `Docker` como submódulo `tooling-local`, opcional y fuera de app deploy. | Bajo si no se promueve a runtime. |
| `Base` | Dependencia explícita para helpers shell, métricas y Telegram. | Medio si `Base` no está disponible localmente. |
| Watcher | Observa eventos, filtra por label y persiste eventos/incidentes. | Bajo/medio por dependencia de Docker real. |
| Heartbeat | Genera snapshot, summary, historial y evento heartbeat. | Bajo si se ejecuta con rutas controladas. |
| APIs | Exponen lectura de health/latest/history/events. | Medio por falta de contrato común/método. |
| SuperAdmin | Vista read-only compacta. | Medio por falta de documentación local y headers. |
| Server uninstall | Borra rutas absolutas con `rm -rf`. | Alto hasta agregar guardas. |

## Hechos verificados

1. `Docker` declara en README que observa Docker desde servidor y web/SuperAdmin.
2. La versión actual reemplaza watcher aislado por arquitectura dependiente de `Base`.
3. `Docker` conserva lógica específica de `docker events`, label gate, anti-spam, heartbeat, snapshots, events JSONL, APIs read-only y vista SuperAdmin.
4. El watcher declara uso de `docker events`, guarda por `DOCKER_WATCH_ENABLED`, label `dockwatch.monitor=true`, persistencia de eventos y envío Telegram opcional.
5. El heartbeat genera snapshot, persiste reportes, prunea historial y permite `--print`, `--force` y `--no-telegram`.
6. Las APIs públicas devuelven JSON directamente, pero no tienen `_common.php` ni guarda de método.
7. Las APIs de SuperAdmin usan `support/api.php`, pero siguen sin `declare(strict_types=1)`, headers y método HTTP explícito.
8. `scripts/dev/smoke.sh` ejecuta lint PHP, tests shell y tests PHP.
9. El auditor local reportó 3 errores documentales y 84 warnings antes de este paquete.
10. El intento de usar `tools/structure_audit/rules/docker_rules.json` falló porque el archivo no existía en el host.

## Hallazgos

### Críticos

No se detectaron hallazgos críticos de ejecución remota en esta auditoría, porque no se modificó ni ejecutó runtime.

### Altos

#### 1. Documentación estructural faltante

El auditor local reportó como errores:

```txt
docs/checklists/auditoria-modularidad-modulo.md
docs/contrato-host-modulo.md
docs/estructura-modulo.md
```

Ruta aplicada: este paquete agrega los tres documentos.

#### 2. `scripts/server/uninstall.sh` usa `rm -rf` sin guardas suficientes

El script elimina:

```txt
/opt/docker-watch
/var/lib/docker-watch
/var/log/docker-watch
/etc/docker-watch
```

Riesgo: error de variable/ruta o ejecución fuera de contexto puede borrar datos operativos. Aunque las rutas son literales, el auditor marca el patrón y conviene agregar helper seguro.

Pendiente: `docs/pendientes/20260708-0010-docker-runtime-safety.md`.

### Medios

#### 1. Contrato API débil

Los endpoints actuales son compactos y devuelven JSON, pero falta:

- `_common.php` o helper común;
- método HTTP permitido;
- `405` + `Allow`;
- shape estable `ok/code/module/data/error`;
- smoke de contrato HTTP/JSON.

Pendiente: `docs/pendientes/20260708-0000-docker-api-contracts.md`.

#### 2. SuperAdmin requiere cierre de frontera y producto read-only

La vista existe, pero el auditor marca falta de documentación local y múltiples headers/strict types.

Pendiente: `docs/pendientes/20260708-0020-docker-superadmin-product.md`.

#### 3. Headers PHP/JS y strict types

Muchos archivos PHP/JS relevantes no tienen header `@file/@brief`; algunos PHP bajo SuperAdmin tampoco tienen `declare(strict_types=1)`.

Riesgo: bajo funcionalmente, medio para auditor estructural.

### Bajos

#### 1. `back/bootstrap.php` declara funciones antes de algunas cargas

El auditor marca `PHP_REQUIRE_AFTER_CODE`. Puede resolverse moviendo cargas arriba o allowlisteando la carga lazy si se justifica.

#### 2. Endpoints/wrappers extremadamente compactos

Varios endpoints son de 5 a 7 líneas. Aunque funcionales, el auditor los clasifica como wrappers sospechosos porque no expresan contrato en el archivo.

## Pendientes propuestos

| Prioridad | Pendiente | Ruta |
|---|---|---|
| P1 | API JSON contracts y method guards. | `docs/pendientes/20260708-0000-docker-api-contracts.md` |
| P1 | Runtime safety para uninstall y comandos server. | `docs/pendientes/20260708-0010-docker-runtime-safety.md` |
| P2 | Producto SuperAdmin read-only y cierre visual/contractual. | `docs/pendientes/20260708-0020-docker-superadmin-product.md` |

## Validaciones no ejecutadas

| Validación | Motivo |
|---|---|
| `git status --short` | No hubo checkout local real. |
| `bash scripts/quality/audit_structure.sh submodules/Docker` | Requiere host local del usuario. |
| `find . -name '*.php' -print0 \\| xargs -0 -n1 php -l` | Requiere checkout local. |
| `BASE_DIR=../Base bash scripts/dev/smoke.sh` | Requiere `Base` inicializado junto a `Docker`. |
| `bin/docker-heartbeat --print --force` | Puede escribir reportes runtime si no se configura temp dir. |
| `bin/docker-watch` | Depende de Docker real o stdin controlado. |

## Comandos reproducibles

Desde `Pruebas`:

```bash
git status --short
git submodule status --recursive | grep 'submodules/Docker' || true
bash scripts/quality/audit_structure.sh submodules/Docker
```

Desde `Pruebas/submodules/Docker`:

```bash
find . -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh

DOCKER_WATCH_REPORTS_DIR="$(mktemp -d)/reports" \
SEND_TELEGRAM=false \
bin/docker-heartbeat --no-telegram --print --force | python3 -m json.tool >/dev/null
```

## Resultado esperado después de aplicar este ZIP

```txt
Summary: 0 error(s), N warning(s), 0 info
```

Los 3 errores documentales deberían cerrarse. Los warnings técnicos quedan vivos hasta una fase de implementación separada.
