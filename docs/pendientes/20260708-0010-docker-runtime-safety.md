# Pendiente P1 — Probar ciclo de instalación, uninstall y rollback Docker

Clasificación: **VERIFY_ONLY** para guards existentes; **KEEP_OPEN** para fallos operativos que surjan.
Owner: `Docker` (scripts, doctor y unidades); servidor/cutover requiere autorización operativa separada.

## Baseline y evidencia

- Inspeccionado Docker/main `b3198162b939ef0ea4e199a3d05f4c363bcbb2be`.
- `scripts/server/uninstall.sh`: dry-run por defecto, `--apply --confirm docker-watch` para mutar y `PURGE_DATA=true` más `--confirm-purge DELETE_DOCKER_WATCH_DATA` para borrar datos; lista fija de destinos y comprobación de symlinks.
- `scripts/server/install.sh`: preflight de root, comandos, paths/unidades legacy; evita importar `server.env` y secretos locales; conserva config instalada y ajusta modo 0600. **Puede habilitar unidades systemd; nunca ejecutarlo como simple test.**
- `scripts/server/installation-doctor.py`: `--deployment` (unidades, binarios, permisos), `--retention` (capacidad estimada), `--runtime` (comandos Docker/systemd de lectura con timeout). El doctor no instala ni repara.
- Tests existentes: `test/shell/docker_install_policy_test.sh` (estático), `test/shell/docker_uninstall_safety_test.sh` (dry-run/bloqueos), `test/python/docker_installation_doctor_test.py` (fixtures de disco y mocks). **No demuestran uninstall real ni rollback.**
- Workflow histórico SUCCESS para `c142337621ad4327c14787a697a72f15cced718a`: https://github.com/lucasborges2001/Docker/actions/runs/39875949580. A partir de `857ad069` el workflow se invoca manualmente; **ninguna suite del HEAD b3198162 ha sido acreditada en un executor real dentro de esta auditoría**.

## Brecha / riesgos

- No hay evidencia de instalación, upgrade, uninstall sin purge, rollback o reinstalación en VM disposable.
- Deben verificarse estado final de `docker-watch.service`, `docker-watch-telemetry.service`, heartbeat service/timer, permisos y rutas persistentes.
- El plan de cutover de una instalación legacy no está automatizado. La guía operativa documenta un caso histórico; **no extrapolar al servidor actual sin comprobarlo**.
- Una caída entre `systemctl stop`, eliminación de unidades y directorios puede dejar estado parcial. Reintentos/rollback/idempotencia no probados.
- `/opt/docker-watch/config/server.env` y override `/etc/docker-watch/docker-watch.env` requieren revisión de ownership/permisos sin volcar valores sensibles.
- Los defaults pueden diferir de `server.env` ya desplegado; la instalación no debe sobrescribir configuración existente.
- No se ha validado que un usuario no root/rootless cumpla los permisos del diseño actual de las unidades (que declaran `User=root`).

## Fases pequeñas y verificables

1. **R0 — Baseline offline (sin servidor):** comprobar repo/HEAD limpio y correr el verificador local, luego tests de seguridad/doctor focales. No gastar minutos de Actions.
2. **R1 — Doctor y fixtures de fallos parciales:** en caso de gap demostrado, agregar tests que simulen unidad faltante, symlink, config insegura, rollback interrumpido. Commit aislado por invariante.
3. **R2 — VM disposable Linux con systemd (requiere autorización):** inventario, backup, instalación; medir permisos, estado de unidades, doctor, snapshot fresco y no-autorestart. Simular reejecución y fallos parciales sin tocar servicios reales de usuario.
4. **R3 — Uninstall/reinstall con y sin purge SOLO en VM:** comprobar preservación de datos por defecto, ausencia de unidades huérfanas, vuelta al baseline y restauración documentada.
5. **R4 — Preflight en servidor autorizado (solo lectura):** comparar instalación legacy vs nueva, rutas, usuario, Docker Engine y estado de reportes. El cutover/deploy real es decisión posterior independiente.

## Comandos seguros ahora (no destructivos)

~~~bash
git rev-parse HEAD
git status --short
bash scripts/dev/verify-local.sh --compact
bash test/shell/docker_install_policy_test.sh
bash test/shell/docker_uninstall_safety_test.sh
python3 -B -m unittest discover -s test/python -p '*installation_doctor_test.py' -v
bash scripts/server/uninstall.sh --dry-run
~~~

En una instalación autorizada y con root/contexto correctos:

~~~bash
python3 scripts/server/installation-doctor.py --deployment --retention
# Solo después de confirmar que la PC/servidor está disponible:
python3 scripts/server/installation-doctor.py --runtime --timeout 10
~~~

`--deployment`/`--retention` comparan contra un filesystem esperado; sin instalación pueden devolver INCOMPLETE/exit 1, no implica automáticamente fallo del producto.

## PASS / FAIL / rollback / cierre

- **PASS offline:** los checks focales se ejecutaron sobre SHA exacto y checkout limpio; los casos de bloqueo fallan como corresponde.
- **PASS VM:** install, doctor, servicios, uninstall, rerun y rollback comprobados con exit codes, rutas permitidas, unidades/estado antes-después y snapshot real; los datos se conservan sin purge.
- **FAIL:** pérdida sin autorización, unidad huérfana, secreto legible, fallback engañoso, rollback incompleto o cambio de estado fuera de allowlist.
- **Rollback:** en una VM, restaurar backup de unidades/binarios/config y validar estado final. **No ejecutar uninstall --apply o install.sh en producción en esta fase.**
- **Cierre:** reporte de VM ligado a SHA/versión, comandos, clasificación de fallos operativos vs producto y evidencia de restauración. La ejecución en servidor definitivo queda como fase separada y autorizada.
