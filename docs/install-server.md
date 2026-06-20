# Instalación en servidor

```bash
sudo BASE_DIR=/opt/base bash scripts/server/install.sh
sudo systemctl start docker-watch.service
sudo systemctl enable --now docker-watch-heartbeat.timer
```

Paths: `/opt/docker-watch`, `/var/lib/docker-watch/reports`, `/var/lib/docker-watch/incidents`, `/var/log/docker-watch/events.jsonl`.
