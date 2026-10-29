# Pendiente P2 — Aceptación de Docker SuperAdmin read-only

Estado: **VERIFY_ONLY** (pantalla y endpoints presentes; renderizado y seguridad con Base/host sin validar).
Owner: `Docker` (UI/read model); `Pruebas` (composición, sesión, autorización y navegación).

## Evidencia verificada

- En Docker/main `b3198162b939ef0ea4e199a3d05f4c363bcbb2be` existen `public_html/superadmin/index.php`, partials de métricas, contenedores, eventos e historial, `public_html/superadmin/dockerFront.md` y endpoints SuperAdmin read-only.
- El modelo contempla CPU, RAM, red, Block I/O, PIDs, estados, health, restart, Compose y snapshots históricos. `container-trend.php` existe como API pública; **no se demostró una visualización integrada de sus tasas en SuperAdmin**.
- Las rutas internas fueron retiradas de varias respuestas y de la vista de contratos; todavía falta verificación HTTP/UI real y consumidores.
- `.github/workflows/quality.yml` es manual-only; último CI histórico comprobado: `c1423376`, no el HEAD actual.
- **Consumer externo Riegos (evidencia del operador, 29/10/2026):**
  `lucasborges2001/riegos@308bfbea76d4b4e331be572bf8cdba3764a63606`
  fija el gitlink Docker `323b9361dadcd90f6fd693821045ccf8ade8342d`,
  proyecta un subconjunto saneado del reporte de contenedores en
  `ServerSnapshotReader.php` y presenta tabla/modal de diagnóstico de
  solo lectura desde su propio endpoint SuperAdmin. En un checkout local
  limpio, `bash scripts/run_testkit.sh all` terminó `OK all`
  (**36/36 suites, 253/253 comandos**), con fixtures del modal, sin
  inspección de Docker daemon ni HTTP/navegador real. La capa escribible
  y rootfs continúan opcionales y no miden volúmenes o imágenes exclusivas.
  **No es aceptación del SuperAdmin propio de Docker, ni del host Pruebas,
  ni de un release nuevo desplegado en servidor**. Mantener este
  pendiente `VERIFY_ONLY` y sus gates HTTP/rol/runtime independientes.

## Gap real

1. **Renderizado reproducible:** falta renderizar UI con snapshot v1, v2, snapshot ausente, vacío, errores de telemetría y eventos con texto sensible simulado.
2. **Seguridad de navegación:** verificar autenticación/autorización aportada por host o servidor; bloquear acceso indebido y no exponer paths, IDs completos, labels, env, raw events ni secretos.
3. **Contrato visual:** verificar tablas, estados degradados y responsive; no inferir gráficos de tasas nuevos a partir de la existencia de la API.
4. **Composición con Base:** resolver Base por SHA realmente fijado, renderizar sin acoplar internals, identificar si los cambios de campos removidos afectan el panel del host.
5. **Estado de operación:** una pantalla renderizada no certifica frescura del snapshot, daemon funcional ni crecimiento medido.

## Siguiente fase (commits condicionales)

- **S1 (solo lectura):** inventariar dependencias UI/host y rutas; preparar escenarios de aceptación y fixtures con información simulada.
- **S2 (test/smoke):** agregar prueba de renderizado HTTP y autorización con host/servicios de prueba; no requerir Docker real para esta etapa.
- **S3 (producto):** corregir únicamente findings reproducibles de UI/contrato, sin añadir controles mutantes.
- **S4 (host, separado):** actualizar gitlink y validar navegación/sesión de Pruebas solo cuando los contratos Docker sean estables.

## Pruebas y cierre

~~~bash
git rev-parse HEAD
git status --short
bash scripts/dev/verify-local.sh --compact
BASE_DIR=/ruta/al/Base-verificado bash scripts/dev/smoke.sh
~~~

El último comando depende de la composición real; no asumir `../Base` ni su SHA. Registrar screenshots o respuestas sanitizadas y tested_sha cuando exista un entorno de prueba autorizado.

- **PASS:** permisos, GET/405, respuesta degradada, fixtures v1/v2, navegación y sanitización verificados mediante HTTP/render real; no hay comandos Docker desde web.
- **FAIL:** acceso sin rol, fuga de secretos/paths, UI que presenta datos de ejemplo como reales, estado degradado presentado sano o contrato roto.
- **Cierre:** evidencia de aceptación del panel y contrato de host en SHA específico. CI histórico o presencia de PHP/HTML no bastan.
