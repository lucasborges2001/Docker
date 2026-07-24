# Pendiente P2 — Docker SuperAdmin read-only productización

## Estado

**Implementado el 2026-07-24. Pendiente de validación runtime con `Base`.**

## Implementado

### Documentación local

```text
public_html/superadmin/dockerFront.md
```

Declara propósito, APIs, partials, datos permitidos/prohibidos, frontera read-only y comandos de validación.

### UI read-only

- estado del engine;
- agregados de CPU, memoria, network, block I/O y PIDs;
- conteos total/running/stopped/unhealthy/monitored;
- cantidad sin límite de memoria y sin healthcheck;
- tabla sanitizada por contenedor;
- estado, health, restarts y uptime;
- proyecto/servicio Compose;
- tendencias desde snapshots históricos;
- eventos, incidentes y Telegram sin secretos;
- layout responsive;
- sin formularios ni acciones Docker.

### APIs

```text
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
public_html/superadmin/api/resources.php
public_html/superadmin/api/container.php
```

Invariantes:

- solo `GET`;
- `405` con `Allow: GET`;
- JSON;
- `Cache-Control: no-store`;
- sin CLI Docker desde HTTP.

### Calidad

`.github/workflows/quality.yml` verifica:

- sintaxis PHP, Bash y Python;
- fixtures deterministas;
- ausencia de comandos mutantes o ejecución arbitraria en `public_html` y `back`.

## Acciones prohibidas

No existen botones ni endpoints para:

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
volume rm
network rm
```

## Evidencia

```text
public_html/superadmin/index.php
public_html/superadmin/partials/metrics.php
public_html/superadmin/partials/containers.php
public_html/superadmin/partials/history.php
public_html/superadmin/docker-superadmin.css
public_html/superadmin/dockerFront.md
public_html/superadmin/support/api.php
var/sample-reports/latest/report.json
```

## Validación reproducible

```bash
find public_html -type f -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh

grep -RInE \
  --include='*.php' --include='*.js' \
  'docker[[:space:]]+(start|stop|restart|kill|exec|rm|rmi)|shell_exec|exec\(|system\(|passthru|proc_open|popen' \
  public_html back || true
```

## Criterio de cierre restante

Para marcarlo como validado, no como solo implementado:

- confirmar el workflow remoto;
- ejecutar smoke completo con `BASE_DIR=../Base`;
- renderizar la pantalla con fixture v2;
- comprobar respuesta degradada sin snapshot/daemon.

No quedan funcionalidades de producto pendientes dentro del alcance read-only de telemetría v2.
