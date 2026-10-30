# Cierre por recuperación de incidentes Docker — piloto 30/10/2026

**Owner:** Docker; **estado:** IMPLEMENTADO_EN_MAIN / PENDIENTE_VALIDACION_Y_DESPLIEGUE.
**Código base:** `Docker/main@2742bcd684794e63fe7a016b4c189843ec7b8ba2`.
**Cambios:** `24946f1526930540157e38c9f02a6036bcc6cc93` (Actor.ID) y `bfd70c21d51c19ebbbbcf77ebfe5736c7f19e8df` (recovery + archive).
**Fronteras:** Docker produce incidentes; Riegos exporta una proyección sanitaria sin `incidents.open` y no debe inventar severidad ni tocar estado del watcher.

## Evidencia del piloto (aportada por el operador; no ejecución del agente)

- Snapshot protegido Docker: `severity=warning`, engine disponible, `unhealthy=0`, `monitoring.errors=0`, `incidents.open=2`. La proyección PHP permanece WARN y omite incidentes por diseño.
- Dos registros persistidos de tipo `die`, inicialmente de 5,9 y 2,5 horas de antigüedad.
- Correlación contra Docker actual: ambos `SAME_ID`, `running=true`, `started_after_original_event=true` usando el `raw.timeNano` de Docker; retrasos de procesamiento del watcher de 0 y 1 segundos. Esto demuestra recuperación de la instancia, **no** salud HTTP ni del producto.
- `docker-watch.service` estaba `active` como `dockwatch`; en el servidor los SHA-256 de `lib/shell/events.sh` (`a2c2769c05259ce60189b721245d0be5ce7a5f7c8ea4f56bd34da3c1d181c1bb`) y `lib/shell/incident.sh` (`6ffb3ed4771f7d80587b6e4f4e19ee6fcd7a81cb9ca810887b211c69280b20b5`) coinciden con el código anterior del repo. No se acreditó el SHA exacto del release completo instalado.

## Regla implementada

- El parser normaliza `Actor.ID` si los campos de ID habituales faltan.
- Un evento `start` intenta resolver `die` y `unhealthy` solo si el ID original y el nuevo corresponden a la misma instancia y la hora original de Docker del `start` es estrictamente posterior a la del incidente.
- Ausencia/conflicto de identidad, evento fuera de orden o timestamp insuficiente: **fail closed**, no resolver.
- Al resolver, el archivo original se renombra a `*.json.<epoch_nanoseconds>.resolved`, preservando su contenido. No coincide con el glob `*.json` usado para contar incidentes abiertos. No se ejecuta reconciliación automática de incidentes históricos.
- El handler `start` registra warning genérico si falla el archivado, sin imprimir identificadores.

## Pruebas y límites

- Ejecutado fuera del repo de usuario: `bash -n` de los archivos focales y los scripts de prueba `docker_event_actor_id_test.sh` y `docker_incident_recovery_test.sh`: PASS. Blobs publicados comparados por SHA con ese staging.
- **No ejecutado:** `scripts/dev/verify-local.sh --compact` sobre checkout Docker completo y limpio, smoke con Base, TestKit remoto (request_id/tested_sha), Docker real, monitoreo de fallos parciales, despliegue, rollback.
- Riesgos aún abiertos: crecimiento/retención de archivos `.resolved`, concurrencia con más de un watcher, y el camino histórico `healthy` → cierre silencioso de `unhealthy` que no fue rediseñado en esta fase. La coincidencia de IDs/nombres depende de los eventos reales.
- La reparación de código en `main` **no modifica** el release `current/docker` del piloto ni su `incidents.open=2`.

## Gates para cerrar

1. En checkout limpio Docker, confirmar `HEAD`, ejecutar verificador offline y pruebas focales, registrar fallos baseline contra introducidos.
2. Integrar módulo mediante gitlink exacto en host cuando corresponda; TestKit con request_id, tested_sha, suite y reporte. Separar **PIPELINE REMOTO** de **VALIDACIÓN DEL PRODUCTO**.
3. Antes del despliegue, comprobar manifest, checksums y reglas locales; planificar respaldo de unidades, config, reportes e incidentes, ventana de mantenimiento y rollback. No reiniciar watcher, limpiar incidentes o cambiar ACL sin autorización operacional **separada**.
4. Tras despliegue autorizado, probar evento `die → start` real sobre instancia descartable. Verificar archivo archivado, contador y snapshot fresco; no usar solo la salida de CLI como PASS.
5. Reconciliar los **dos registros históricos** únicamente mediante operación aprobada con verificación de ID original, `StartedAt` posterior a `raw.timeNano`, doble verificación justo antes de archivar, respaldo y rollback. No borrarlos por el mero hecho de que exista código nuevo.
6. Cierre: Docker `incidents.open=0` (si no hay incidentes nuevos), severidad justificada, monitoreo sin degradación, sin exposición de secretos y pruebas de producto proporcionales. Boot WARN/reboot requerido es otra deuda, no cierra al resolver Docker.
