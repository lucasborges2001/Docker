# Docker SuperAdmin — contrato read-only

## Propósito

Mostrar estado del engine, recursos de contenedores monitoreados, historial, eventos, incidentes y estado de Telegram sin ejecutar operaciones sobre Docker.

## Fuente de datos

La pantalla usa `DockerStatusService` y snapshots normalizados. No invoca Docker CLI desde HTTP.

APIs disponibles:

```text
api/latest.php
api/history.php
api/events.php
api/probe.php
api/resources.php
api/container.php?container_ref=<ref>
```

Todas las APIs:

- aceptan únicamente `GET`;
- responden JSON;
- usan `Cache-Control: no-store`;
- devuelven `405` con `Allow: GET` para otros métodos.

## Componentes

```text
partials/hero.php
partials/status.php
partials/metrics.php
partials/containers.php
partials/telegram.php
partials/events.php
partials/history.php
partials/contracts.php
```

`metrics.php` muestra agregados. `containers.php` muestra detalle sanitizado por contenedor. `history.php` muestra tendencias de snapshots propios de Docker.

## Datos permitidos

- versión y disponibilidad del engine;
- refs sanitizadas;
- nombre sanitizado;
- proyecto/servicio Compose;
- estado, health, CPU, memoria, red, block I/O, PIDs, restarts y uptime;
- eventos, incidentes y timestamps.

## Datos prohibidos

- env vars y secrets;
- mounts;
- labels completas;
- inspect completo;
- container ID completo;
- path del socket;
- logs completos de contenedor.

## Acciones prohibidas

No agregar formularios, botones, endpoints ni JavaScript para:

```text
start
stop
restart
kill
exec
rm
rmi
prune
recreate
compose down
```

Cualquier futura mutación requiere una especificación y autorización separadas; no forma parte de Docker SuperAdmin.

## Validación

```bash
find public_html -type f -name '*.php' -print0 | xargs -0 -n1 php -l

grep -RInE \
  --include='*.php' --include='*.js' \
  'docker[[:space:]]+(start|stop|restart|kill|exec|rm|rmi)|shell_exec|exec\(|system\(|passthru|proc_open|popen' \
  public_html back || true
```

El workflow `.github/workflows/quality.yml` ejecuta esta frontera estática en cada push y pull request.
