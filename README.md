# Docker Watch por Telegram (Ubuntu + systemd timer)

Watchdog operativo de Docker que envía notificaciones a Telegram.

Principios:
- **Observabilidad primero**: te avisa con contexto (estado + contenedores + status).
- **Sin “auto-restart” por unhealthy**: si un healthcheck falla, **solo notifica**.
- (Opcional) `RESTART_ON_STOP=true` reinicia únicamente contenedores STOPPED/EXITED, con cooldown anti-loop.

> El PDF completo con el paso a paso está en `docs/Docker.pdf`.

## Requisitos
- Ubuntu + systemd
- Docker instalado (`docker` CLI + `docker.service`)
- `curl`, `iproute2`, `util-linux` (flock)

## Instalación rápida

```bash
git clone <este-repo>
cd docker-watch
sudo ./scripts/install.sh
sudo nano /opt/docker-watch/.env
sudo systemctl start docker-watch.service
journalctl -u docker-watch.service -b --no-pager
```

El monitoreo periódico se ejecuta vía timer:

```bash
systemctl status docker-watch.timer --no-pager
```

## Configuración (`/opt/docker-watch/.env`)

Obligatorios:
- `BOT_TOKEN`
- `CHAT_ID`

Opcionales:
- `ALERTS_ONLY=true` (solo envía si hay alertas)
- `IGNORE_CONTAINERS="db,redis,..."` (por nombre o id)
- `ONLY_THIS_COMPOSE="mi_proyecto"` (filtra por label de compose)
- `RESTART_ON_STOP=true` (solo STOPPED/EXITED; NO unhealthy)
- `RESTART_COOLDOWN_SEC=600`

## Frecuencia del timer
Por defecto: cada 5 minutos (ver `systemd/docker-watch.timer`).

## Troubleshooting
- Logs:
  ```bash
  journalctl -u docker-watch.service -b --no-pager
  ```
- Verificar acceso al socket:
  ```bash
  ls -l /var/run/docker.sock
  id dockerwatch
  ```
  Si no tiene acceso, reiniciá el servicio luego de agregar al grupo docker:
  ```bash
  sudo systemctl restart docker-watch.service
  ```

## Desinstalar
```bash
sudo ./scripts/uninstall.sh
```

## Estructura

```
.
├─ docker-watch.sh
├─ .env.example
├─ systemd/
│  ├─ docker-watch.service
│  └─ docker-watch.timer
├─ scripts/
│  ├─ install.sh
│  └─ uninstall.sh
└─ docs/Docker.pdf
```
