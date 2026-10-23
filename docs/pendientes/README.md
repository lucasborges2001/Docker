# Pendientes — Docker Watch

Índice de deuda **real** y validaciones pendientes, organizado para continuar por commits pequeños.
Actualizado: 2026-10-22 (hora local). Repositorio owner: `lucasborges2001/Docker`.

## Estado y evidencia de referencia

- Baseline de **código** auditado: Docker/main `b3198162b939ef0ea4e199a3d05f4c363bcbb2be`. Los commits posteriores de esta actualización son **sólo documentales**.
- GitHub Actions: `.github/workflows/quality.yml` tiene únicamente `workflow_dispatch`; **no usar workflows automáticos** como validación por defecto.
- Última suite histórica GitHub Actions observada: `c142337621ad4327c14787a697a72f15cced718a`, SUCCESS: https://github.com/lucasborges2001/Docker/actions/runs/39875949580. **No valida el HEAD actual.**
- Verificador offline disponible: `scripts/dev/verify-local.sh --compact` (17 grupos de checks, sin Docker ni Base). **No hay en esta auditoría una ejecución real registrada contra el checkout limpio del HEAD.**
- Referencias de composición leídas: `Base/main=ac623f037aa1a9d1e605df5a670c426596d922ac`; en `Pruebas/main`, `Base` apunta a `60a71f0fac829990f47bcc26d13e954e56ba9c88` y `Docker` a `435f9cebe1d8d8067a32a18c64de7f31040c2986`. No actualizados.
- El servidor y Docker Engine reales, HTTP con autenticación, instalación/uninstall y TestKit integrado **no están verificados**.

## Índice de pendientes vivos

| Documento | Clase | Prioridad | Gap que falta cerrar | Owner |
|---|---|---|---|---|
| [Contratos API y compatibilidad](20260708-0000-docker-api-contracts.md) | **KEEP_OPEN** | P1 | Inventario de consumidores, autorización y smoke HTTP/405/errores | Docker + adapters Pruebas |
| [Instalación, uninstall y rollback](20260708-0010-docker-runtime-safety.md) | **VERIFY_ONLY / KEEP_OPEN** | P1 | Ensayo de VM disposable, fallos parciales y rollback, luego cutover autorizado | Docker / operación |
| [Aceptación SuperAdmin read-only](20260708-0020-docker-superadmin-product.md) | **VERIFY_ONLY** | P2 | Render/UI, ausencia de secretos y sesión/rol con Base/host real | Docker + Pruebas |
| [Telemetría, tráfico, almacenamiento e historial](20261022-0000-docker-telemetry-coverage.md) | **KEEP_OPEN** | P1/P2 | Tasas parciales, volúmenes/logs/imágenes, costos, retención real y alertas | Docker |

Clasificaciones de Base: `KEEP_OPEN` = deuda/decisión/implementación no cerrada; `VERIFY_ONLY` = implementación existente que todavía requiere evidencia operativa. No usar `CLOSE_AND_PROMOTE` sin evidencia y autorización de lifecycle. **No borrar documentación.**

## Orden recomendado para las siguientes iteraciones

| Fase | Trabajo pequeño | Precondición | Entregable y gate |
|---|---|---|---|
| **F0 — Baseline local** | Ejecutar verificador offline en checkout limpio del SHA exacto y clasificar fallos | Identificar Docker/Base HEAD y estado Git | Evidencia de comandos, SHA, exit codes y PASS/FAIL real; sin workflow |
| **F1 — Frontera HTTP** | Inventario consumidores + contratos de autenticación/GET/405 y sanitización | F0 válido, sin asumir servidor HTTP disponible | Tests focales; decisión versionado/compatibilidad antes de cambios breaking |
| **F2 — Safety de despliegue** | VM descartable para instalación/uninstall, permisos, doctor, fallos parciales y rollback | F0 y autorización de VM (no servidor real) | Reporte VM, backups/rollback, pruebas de preservación de datos |
| **F3 — Métricas de contadores** | Casos de falta parcial, resets y continuidad de engine | F0 + contratos de tasas | Fixtures/código focal por commits y tasas nunca engañosas |
| **F4 — Crecimiento de almacenamiento** | Fuentes read-only para writable layer/volúmenes/logs/imágenes; sin doble conteo | F3 y auditoría de fuentes/semántica | Parsers/tests; collector opt-in solo si hay gap demostrado |
| **F5 — Retención, capacidad y doctores** | Ensayos de cardinalidad, locks, tamaño, cuota, antigüedad y costo | F4 o muestra representativa | Horizontes medidos, alertas del doctor accionables y overhead aceptado |
| **F6 — Aceptación SuperAdmin** | Render degradado/v1/v2, rol, cabeceras y navegación | F1 + composición de prueba con Base | Smoke HTTP/UX con evidencia y sin exposición de datos |
| **F7 — Alertas de crecimiento** | Histéresis, recuperación, deduplicación, Telegram simulado | F3–F5 comprobados | Escenarios PASS/FAIL de concurrencia y fallos parciales, sin spam |
| **F8 — Pruebas/servidor** | Integrar gitlink exacto, TestKit y luego cutover operativo separado | Contratos estables + autorización explícita de integración/deploy | tested_sha/gitlinks/request_id, producto separado del pipeline; plan de rollback |

No todas las fases requieren código. Primero verificar si Base/Boot/Docker ya tienen un contrato aplicable; asignar el cambio a su owner real, no copiar internals entre módulos. Después de cada fase volver a resolver `main`: estas referencias son un **baseline histórico**, no una orden de usar latest.

## Flujo sin gasto de GitHub Actions

~~~bash
# Desde el root real del checkout Docker; inspeccionar antes de escribir.
git branch --show-current
git rev-parse HEAD
git status --short
bash scripts/dev/verify-local.sh --compact
~~~

- El verificador no hace deploy, no ejecuta comandos Docker reales ni TestKit; presenta resumen temporal y no publica automáticamente reporte durable. Si se necesita evidencia, capturar la salida en una ubicación privada e ignorada por Git, anotando el SHA.
- Si el checkout de Base fijado realmente publica `bin/base-script-timing.py`, reutilizar su contrato `base.script-timing.v1` para medir y resumir spans; no crear instrumentación duplicada en Docker.
- Evitar ejecución manual de workflows salvo orden explícita; `workflow_dispatch` puede consumir minutos.
- Para tests remotos, **PIPELINE REMOTO** (executor/request/report/commit) es independiente de **VALIDACIÓN DEL PRODUCTO** (métricas/API/servidor). Un PASS del pipeline no convierte un FAIL de producto en PASS.
- Si hay modificaciones existentes en un checkout, clasificarlas antes de ejecutar tests o atribuir resultados a su SHA.

## Política de cambio, evidencia y cierre

1. Resolver repo/branch/baseline, AGENTS.md y reglas locales; verificar estado Git. Los cambios de documentación no autorizan escribir código ni modificar el servidor.
2. Un commit por contrato/invariante; scripts de diagnóstico preferentemente read-only, sin comandos arbitrarios ni escritura de secretos.
3. Orden de validación: sintaxis → unitarios → contrato → integración focal → smoke → TestKit/servicios cuando correspondan.
4. Registrar: `baseline_sha`, SHA probado, gitlinks, suite/comando, exit codes, plataforma, evidencia y clasificación introduced/baseline/environment/omitted/operational/product.
5. PASS requiere evidencia proporcional. FAIL debe permanecer abierto con reproducción, impacto, owner y siguiente prueba; no basta imprimir PASS en un script.
6. Rollback de código = revertir commit focal y reevaluar contratos/consumidores. Rollback de servidor exige backup/operación autorizada, no se infiere del Git history.

**Próxima acción concreta: F0**, ejecutar `verify-local.sh --compact` sobre el checkout real limpio de Docker y registrar resultado exact-SHA. Recién entonces elegir F1 o F3 según findings; F2 no debe realizarse fuera de una VM autorizada.
