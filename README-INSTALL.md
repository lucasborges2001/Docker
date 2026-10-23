# Instalación Docker Watch

## Aplicar ZIP

```bash
cd ~/Escritorio/Proyectos/Pruebas/submodules/Docker
unzip -o /ruta/al/docker-base-observability-files.zip
chmod +x bin/* scripts/server/*.sh scripts/web/*.sh scripts/dev/*.sh test/shell/*.sh docker-watch.sh heartbeat.sh
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

## Servidor

```bash
sudo BASE_DIR=/opt/base bash scripts/server/install.sh
sudo nano /opt/docker-watch/config/server.env
# Sólo después de inspeccionar y migrar una instalación legacy, si existe:
sudo systemctl start docker-watch.service docker-watch-telemetry.service docker-watch-heartbeat.timer
sudo systemctl start docker-watch-heartbeat.service

# Diagnóstico: disk-only primero; probes reales opcionales luego del cutover:
python3 scripts/server/installation-doctor.py
python3 scripts/server/installation-doctor.py --runtime --timeout 10
```

Convención elegida:

- instalación: `/opt/docker-watch`
- env principal: `/opt/docker-watch/config/server.env`
- override opcional: `/etc/docker-watch/docker-watch.env`
- reportes: `/var/lib/docker-watch/reports`
- incidentes: `/var/lib/docker-watch/incidents`
- eventos: `/var/log/docker-watch/events.jsonl`

No se instalan secretos.

## Web/SuperAdmin

```bash
bash scripts/web/package-web.sh
```

La parte web no ejecuta `docker`, `systemctl` ni comandos del sistema. Solo lee snapshots y JSONL.

## Validación

```bash
find . -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

Los tests no requieren Docker real y no envían Telegram real.

## Diagnóstico y desinstalación

Antes de habilitar servicios, inspeccionar el resultado del doctor:

```bash
python3 scripts/server/installation-doctor.py --deployment
python3 scripts/server/installation-doctor.py --retention
```

La configuración existente en `/opt/docker-watch/config/server.env` se
preserva; el instalador aplica permisos 0600 y bloquea unidades legacy
incompatibles. No ejecutarlo sobre una instalación legacy sin backup/cutover.

El desinstalador planifica sin mutar si no se solicita `--apply`:

```bash
bash scripts/server/uninstall.sh --dry-run
PURGE_DATA=true bash scripts/server/uninstall.sh --dry-run
```

Los comandos efectivos requieren **una autorización operativa independiente**,
backup y confirmación explícita. El primer nivel `--apply --confirm docker-watch`
deshabilita watcher, telemetry y heartbeat y elimina binarios/unidades;
el segundo nivel de purga de datos añade `PURGE_DATA=true` y
`--confirm-purge DELETE_DOCKER_WATCH_DATA`. No ejecutar una desinstalación
real como parte del diagnóstico. Consultar
`docs/pendientes/20260708-0010-docker-runtime-safety.md`.
