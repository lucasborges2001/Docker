# Pendiente P1 — Validación operacional de instalación y uninstall Docker

## Estado al 2026-10-22

**Guardas implementadas y CI PASS; aplicación/desinstalación real no verificada.**
No borrar este pendiente hasta completar la validación de un entorno controlado.

## Evidencia y cambios

- `scripts/server/uninstall.sh`: plan por defecto, `--apply --confirm docker-watch`,
  `--confirm-purge DELETE_DOCKER_WATCH_DATA` adicional cuando `PURGE_DATA=true`,
  lista fija de destinos y bloqueo de symlinks.
- Uninstall deshabilita también `docker-watch-telemetry.service`, detiene
  el heartbeat oneshot y recarga systemd.
- `scripts/server/install.sh`: preflight de root, binarios, paths y unidades
  legacy; `rsync` excluye secrets locales y bytecode; `server.env` usa 0600.
- Doctor `scripts/server/installation-doctor.py --deployment` verifica
  archivos de unidades, ejecutables, secret mode y directorios, sin ejecutar Docker.
- `test/shell/docker_uninstall_safety_test.sh` sólo prueba dry-run y guards
  de confirmación. `test/shell/docker_install_policy_test.sh` es prueba
  **estática**, no instalación real.
- GitHub Actions para Docker/main:
  https://github.com/lucasborges2001/Docker/actions/runs/39875681359
  (evidencia histórica del SHA a668b4c, no prueba del servidor).

## Gap operativo y riesgos

- No se ejecutó el flujo de uninstall/reinstall/rollback en VM disposable.
- No se comprobaron cambios de usuario/grupo, systemd, Docker daemon ni
  permisos en /var/lib/docker-watch del servidor real.
- `install.sh` aún habilita unidades systemd; una unidad legacy se bloquea
  en lugar de migrarse automáticamente. Requiere cutover autorizado.
- Los comandos con `--apply` **son destructivos**, nunca ejecutarlos en
  el host real sin backup e inventario previos.
- Una interrupción después de parar unidades puede dejar estado parcial.
  Rollback operativo exige backup de binarios, unidades y configuración.

## Validación reproducible no destructiva

```bash
bash -n scripts/server/install.sh
bash -n scripts/server/uninstall.sh
bash test/shell/docker_install_policy_test.sh
bash test/shell/docker_uninstall_safety_test.sh
python3 -m unittest discover -s test/python -p '*installation_doctor_test.py' -v
python3 scripts/server/installation-doctor.py --deployment
```

## Criterio PASS/FAIL y cierre

- PASS CI: lints, tests de contrato y safety pasan en el SHA candidato.
- PASS operativo: una VM disposable verifica backup, install, runtime doctor,
  uninstall sin purge, reinicio y rollback; la telemetría emite snapshot fresco.
- FAIL: alguna unidad queda habilitada/huérfana después de uninstall,
  datos borrados con purge no solicitado, config expuesta o rollback imposible.
- Cierre: evidencia adjunta de VM con hashes de artefactos, comandos ejecutados,
  códigos de salida, clasificación y rollback; luego validación del servidor
  sólo con autorización independiente.
