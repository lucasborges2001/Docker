# Docker Watch (events) + Heartbeat diario (Telegram)

Este repo instala un watcher de Docker basado en **docker events** (die/unhealthy) y un **heartbeat diario** por Telegram.

## Qué instala

- **Watcher continuo**: `docker-watch.service`
  - Escucha `docker events`
  - Envía alertas por:
    - `die`
    - `health_status: unhealthy`
  - Tiene:
    - dedupe por TTL
    - retry/backoff para Telegram
    - auto-restart opcional con rate limit

- **Heartbeat diario**: `docker-watch-heartbeat.timer`
  - Envía un mensaje por día con:
    - lista de contenedores monitoreados (running)
    - subset unhealthy

> El PDF de referencia está en `docs/Docker.pdf`.

## Requisitos

- Ubuntu con systemd
- Docker instalado (socket en `/var/run/docker.sock`)
- Paquetes recomendados: `curl`, `util-linux` (flock)

## Instalación

```bash
sudo ./scripts/install.sh
sudo nano /opt/docker-watch/.env
sudo systemctl restart docker-watch.service
sudo systemctl start docker-watch-heartbeat.service   # prueba inmediata
```

## Filtrado por label (recomendado)

En tus contenedores/compose agregá:

```yaml
labels:
  dockwatch.monitor: "true"
```

Y en `/opt/docker-watch/.env`:

```bash
MONITOR_LABEL_KEY="dockwatch.monitor"
MONITOR_LABEL_VALUE="true"
```

## Tests rápidos

**die**
```bash
docker run --rm --name dw-test --label dockwatch.monitor=true alpine sh -c 'exit 1'
```

**unhealthy**
```bash
docker run --name dw-hc -d --rm --label dockwatch.monitor=true   --health-cmd="sh -c 'exit 1'" --health-interval=5s --health-retries=1   alpine sleep 9999
```

## Logs

```bash
journalctl -u docker-watch.service -f
journalctl -u docker-watch-heartbeat.service -b --no-pager
systemctl list-timers --all | grep docker-watch-heartbeat
```

## Desinstalar

```bash
sudo ./scripts/uninstall.sh
```

## Legacy timer (deprecated)

Existe `systemd/docker-watch.timer` como referencia del modo “scan periódico”.
**No se instala** por defecto (quedó solo como legacy).
