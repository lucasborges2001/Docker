# Contrato events.jsonl

Cada línea es JSON. Eventos documentados: `die`, `health_status: unhealthy`, `health_status: healthy`, `restart`, `start`, `stop`, `heartbeat`, `watcher_start`, `watcher_stop`, `error`.

Ejemplo: `{"type":"die","severity":"error","container_name":"app","incident_key":"app:die"}`.
