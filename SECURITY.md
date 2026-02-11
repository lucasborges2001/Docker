# Security

- **No commitees** `.env` (contiene `BOT_TOKEN`).
- El servicio corre como usuario no-root (`dockerwatch`) con hardening de systemd.
- **Acceso a Docker**: pertenecer al grupo `docker` equivale a privilegios elevados en el host. Usalo solo en servidores donde lo aceptes.
- Política: **NO reinicia contenedores UNHEALTHY**. Por defecto solo avisa.
- Si activás `RESTART_ON_STOP=true`, reinicia únicamente contenedores STOPPED/EXITED (con cooldown anti-loop).
