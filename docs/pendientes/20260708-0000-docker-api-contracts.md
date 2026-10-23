# Pendiente P1 — Contratos HTTP, seguridad y compatibilidad Docker

Estado: **KEEP_OPEN** (contratos implementados; consumidores y HTTP real no verificados).
Owner: `Docker` para endpoints/normalización; `Pruebas` para adapters, autenticación del host e integración.

## Baseline y evidencia

- Código inspeccionado en Docker/main `b3198162b939ef0ea4e199a3d05f4c363bcbb2be`: `public_html/api/_common.php`, `public_html/superadmin/support/api.php`, `back/metrics/DockerSnapshotNormalizer.php` y `public_html/api/container-trend.php`.
- Los guards declaran GET-only, 405/`Allow: GET`, JSON y `Cache-Control: no-store`. **Eso es evidencia estática, no una respuesta HTTP probada.**
- Se retiraron de respuestas públicas rutas internas como `latest_path`, `events_path`, `history[].path`, `probe.paths` y artefactos con paths. El lector de eventos proyecta campos permitidos. **Son cambios potencialmente breaking** para consumidores que esperaban esos campos.
- Existe la API `public_html/api/container-trend.php?container_ref=<ref>&limit=20`; el cálculo de tasas tiene tests de fixtures, no smoke HTTP.
- Último workflow histórico observado: SUCCESS en `c142337621ad4327c14787a697a72f15cced718a` (https://github.com/lucasborges2001/Docker/actions/runs/39875949580). No demuestra el HEAD actual.
- Desde `857ad069`, `.github/workflows/quality.yml` usa sólo `workflow_dispatch`; no hay CI automático por push/PR.

## Gap y decisiones abiertas

1. **Inventario de consumidores:** verificar qué adapters/paneles de Pruebas consumen `latest`, `history`, `events`, `health`, `resources`, `container` y `container-trend`. No asumir compatibilidad por ser JSON.
2. **Autorización real:** inspeccionar sesión, rol, configuración del reverse proxy y exposición pública de cada API; los guards de método por sí solos **no son autenticación**.
3. **Contrato de errores y envoltorios:** conservar formas actuales hasta inventariar consumidores. Si se requiere envelope `ok/code/data/error`, preferir versión nueva o negociación explícita; no cambiar los endpoints existentes a ciegas.
4. **HTTP real:** no se han comprobado GET, POST/405, `Allow`, `Content-Type`, no-cache, límites, ausencia de secretos, respuestas sin snapshot ni rutas antiguas con servidor PHP/host real.
5. **Integración:** actualizar contratos/documentación del host **sólo** tras decidir la compatibilidad; no copiar internals ni acoplar módulos.

## Plan por commits pequeños (aún no ejecutado)

- **A1 — Auditoría de consumidores (solo lectura):** tabla consumidor/ruta/shape esperado/gitlink; clasificar campos retirados y decisión de compatibilidad.
- **A2 — Smoke HTTP focal en Docker:** fixture v1/v2 y ausencia de snapshot; GET/POST, cabeceras, errores y límites. TestKit/runner sólo si el entrypoint exacto está disponible.
- **A3 — Adaptación mínima (condicional):** corregir únicamente divergencias verificadas; evitar una migración general de envelope sin necesidad.
- **A4 — Composición Pruebas (owner host):** adapter público, gitlink exacto y validación remota/host en fase explícita.

## Comandos y evidencia esperada

~~~bash
git rev-parse HEAD
git status --short
bash scripts/dev/verify-local.sh --compact
php test/php/DockerPathsTest.php
php test/php/DockerEventReaderTest.php
php test/php/DockerTrendBuilderTest.php
~~~

Estos comandos comprueban **contratos locales**; no reemplazan un servidor HTTP. Para el smoke HTTP registrar URL base autorizada, método, código, headers, shape de respuesta sanitizado y tested_sha, sin secretos. No levantar/desplegar servicios sin autorización.

## PASS / FAIL / cierre

- **PASS local:** verificador y tests focales ejecutados sobre checkout limpio con SHA registrado.
- **PASS HTTP:** casos positivos, negativos, degradados y sin autenticación autorizada se comportan según contrato, sin secretos ni paths y sin acciones Docker.
- **PASS integración:** consumidores inventariados y compatibles o migrados mediante contrato público; Pruebas valida gitlink exacto.
- **FAIL:** exposición indebida, cambio de forma no coordinado, respuestas HTTP distintas del contrato o dependencia de internals.
- **Cierre:** adjuntar evidencia HTTP y de consumo contra SHAs exactos; decidir explícitamente si el envelope uniforme se descarta o se versiona. No cerrar con lint/fixture únicamente.
