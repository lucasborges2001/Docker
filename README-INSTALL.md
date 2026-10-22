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
