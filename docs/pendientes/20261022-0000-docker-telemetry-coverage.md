# Pendiente P1/P2 — Crecimiento de contenedores, tráfico, almacenamiento e historial

Clasificación: **KEEP_OPEN** (implementación parcial; medición real, límites y alertas pendientes).
Owner: `Docker` para métricas de engine/contenedores y su persistencia; `Base` sólo para timing/reporting reusable; `Pruebas` para integración. No replicar CPU/disco/red general del host (owner: `Boot`).

## Estado verificado al preparar próximas fases

- Docker/main inspeccionado: `b3198162b939ef0ea4e199a3d05f4c363bcbb2be`, sólo lectura. La implementación tiene snapshots v2, contadores RX/TX y Block I/O, RAM/CPU, historial, `DockerCounterRate`, `DockerTrendBuilder`, `container-trend.php` y tamaño de capa escribible opcional.
- `DOCKER_TELEMETRY_STORAGE_ENABLED=false` por defecto. Con opt-in, `docker inspect --size` aporta `writable_layer_bytes` y `rootfs_bytes`; no mide volúmenes, logs ni espacio exclusivo de imágenes.
- Retención predeterminada: 60 s, 30 días, hasta 50.000 snapshots y 256 MiB. A 60 s se precisan 43.200 muestras en 30 días: el límite de **cantidad** es suficiente; el de **bytes** puede cortar antes. No hay medición real de tamaño medio ni garantía de 30 días.
- `DockerHistoryService` acota la cantidad de reportes decodificados y `DockerHistoryFiles` restringe nombres timestamp/symlinks; todavía hay que medir comportamiento con muchos directorios y en presencia de archivos dañados.
- Código revisado: `DockerCounterRate::between` rechaza **todas** las tasas si falta o disminuye **cualquiera** de los cuatro contadores. Esto evita combinar muestras inconsistentes, pero una ausencia de Block I/O también suprime tasas RX/TX válidas: decidir semántica por métrica y documentar antes de cambiarla.
- `DockerTrendBuilder` usa `instance_ref` y versión del engine como señal de continuidad; la identidad de engine/contexto no está definida de forma estable. No unir historias de engines diferentes por su misma versión.
- Último CI histórico `c142337621ad4327c14787a697a72f15cced718a`: SUCCESS (https://github.com/lucasborges2001/Docker/actions/runs/39875949580). Tras desactivar triggers automáticos, **no hay PASS registrado para el HEAD b3198162** en un checkout real.
- `Base/main` observado `ac623f037aa1a9d1e605df5a670c426596d922ac` publica `bin/base-script-timing.py` y contrato de salida compacta. `Pruebas/main` fija `Base` en `60a71f0fac829990f47bcc26d13e954e56ba9c88` y `Docker` en `435f9cebe1d8d8067a32a18c64de7f31040c2986`. No asumir que el Base instalado tiene el CLI de timing; comprobar gitlink/entrypoint.

## Brechas separadas por dominio

| ID | Gap | Prioridad | Riesgo si se ignora |
|---|---|---|---|
| T1 | Contadores/velocidades con resets, gaps, ausencia parcial y cambio de engine/contexto | P1 | Tasas nulas o engañosas, discontinuidad no reconocida |
| T2 | Tamaño actual y crecimiento de volúmenes, logs e imágenes; fuentes y atribución sin doble conteo | P1 | Confundir I/O con espacio utilizado o sumar almacenamiento compartido |
| T3 | Costo y permisos de `inspect --size` y de llamadas CLI, con timeout/carga real | P1 | Demoras, bloqueo de collector o datos parciales ocultos |
| T4 | Retención real: cardinalidad, capacidad por bytes, rotación, locks, reinicios y frescura del snapshot | P1 | Historia incompleta y consumo no acotado |
| T5 | Diagnósticos de permisos/espacio/disco y reportes compactos de evidencia, reutilizando Base cuando corresponda | P1 | Fallos operativos difíciles de localizar |
| T6 | Alertas de crecimientos anómalos (RAM, capa escribible, volumen, tasas de red) con ventana, histéresis y deduplicación | P2 | Falsos positivos, tormenta de Telegram y alertas sin persistencia |
| T7 | API/HTTP y vista de tendencias consumibles, con autorización del host | P1 | Exposición de datos, dependencias a internals o gráficos incorrectos |

Los pendientes HTTP y SuperAdmin tienen dueños/criterios detallados en
`20260708-0000-docker-api-contracts.md` y `20260708-0020-docker-superadmin-product.md`; no duplicar su implementación aquí.

## Roadmap de commits pequeños

### T0 — Baseline local y evidencia (primero; sin código nuevo)

- Registrar repo, rama, HEAD, checkout clean/dirty, SHA de Base consumido.
- Ejecutar `bash scripts/dev/verify-local.sh --compact` en un **checkout real**. Capturar stdout/stderr, exit code, SHA y plataforma en evidencia local privada/ignorada por Git.
- Si aparece FAIL, clasificar introduced/baseline/environment antes de añadir funciones. No atribuir un PASS a un SHA si el árbol está sucio.
- Criterio: resultado explícito y reproducible, no simplemente el texto PASS de un test.

### T1 — Corrección mínima de tasas y continuidad

- Fijar contrato de invalidación por contador o por snapshot y tratamiento de ausencia parcial; no cambiar formato de salida v2 sin contrato.
- Casos: RX/TX válido con Block I/O ausente, counter reset, recreación, timestamp invertido/duplicado, cambio de engine, contenedor ausente, múltiples intervalos, intervalos grandes.
- Extender `DockerCounterRate`/`DockerTrendBuilder` y sus tests **sólo si los casos muestran un gap**. Un commit para semántica y otro para adaptación API si hace falta.
- PASS: no tasas negativas, cero sólo si realmente hay cero, null cuando no se puede calcular; continuidad e identidad bien delimitadas.

### T2 — Auditoría de almacenamiento antes de agregar collectors

- Inventariar fuentes de datos Docker para writable layer, volúmenes, imágenes y logs y quién es owner de cada métrica; no usar Block I/O como ocupación.
- Decidir identidad, unidades, semántica de compartidos, cadencia, límites, nullability y sensibilidad. Evitar leer contenidos de logs/secrets.
- Probar parsers con fixtures y faltantes; luego collector read-only **opt-in**, límite de carga/timeout y salida degradada.
- PASS: sin doble conteo, paths/secretos ausentes del API, datos desconocidos en null, fuentes verificables.

### T3 — Retención, capacidad y doctor

- Ensayar tamaños de snapshot y número de directorios (incluidos inválidos), locks y crash durante persistencia; verificar poda sin borrar rutas externas.
- Establecer horizonte realmente soportado por 256 MiB; evaluar downsampling sólo si hay evidencia de insuficiencia, no aumentar almacenamiento a ciegas.
- Ampliar doctor con códigos estables para falta de espacio, permisos, snapshot viejo/corrupto y overhead de collector si los tests demuestran necesidad.
- PASS: historia acotada, métricas correlacionadas con SHA/instancia y doctor distingue bloqueo de entorno de fallo de producto.

### T4 — Validación con Docker real (requiere entorno autorizado)

- Medir `docker ps`, `inspect --size`, `stats`, permisos/rootless, carga real, recreación y resets; fijar timestamps, referencias y timeout.
- Comparar muestras antes/después contra el daemon, no sólo JSON fixture. Separar desempeño/costo de exactitud de producto.
- PASS: snapshots frescos, tasas y tamaños coherentes, tiempo admisible medido; ningún comando de mutación.

### T5 — Alertas y composición (después de T1–T4)

- Contratos de umbral, ventana, histéresis, idempotencia y recuperación; validar escenarios de restart, caída de collector y envío parcial.
- Integrar con la capacidad de notificaciones ya existente (no crear otro canal sin gap). La entrega Telegram real requiere autorización.
- Validar API/UX vía pendientes HTTP/SuperAdmin; `Pruebas` actualiza gitlink en fase propia, con tested_sha y evidencia de TestKit.
- PASS: alertas accionables, sin duplicados, fallos parciales observables, host consume contrato público.

## Validación sin minutos de workflows

~~~bash
git status --short
git rev-parse HEAD
bash scripts/dev/verify-local.sh --compact
php test/php/DockerCounterRateTest.php
php test/php/DockerTrendBuilderTest.php
php test/php/DockerHistoryFilesTest.php
python3 -B -m unittest discover -s test/python -p '*storage_collector_test.py' -v
python3 scripts/server/installation-doctor.py --retention --report-bytes 8192
~~~

El doctor requiere una instalación válida para devolver exit 0 global; interpretar por separado `classification` y `retention.status`. Si Base instalada ofrece timing público, usar `bin/base-script-timing.py run --execute` y `report` contra el comando autorizado, registrando repo_sha, perfil y cold/warm. **No replicar timing o reporting en Docker.** Las pruebas reales de daemon, HTTP y servidor son fases separadas; GitHub Actions sólo manual y no solicitado.

## FAIL y criterio de cierre

- **FAIL:** contador negativo por cálculo, tasa calculada entre instancias distintas, tamaño compartido duplicado, silencio ante fallos de recolección, pérdida de historial, symlink fuera de scope, datos sensibles expuestos, costo operativo excesivo, alertas repetidas.
- **PASS local:** fixtures del SHA limpio ejecutados; **PASS producto:** mediciones comparadas con Docker real, permiso y retención verificados, APIs seguras y costo aceptado.
- Cerrar cada T1–T5 **por evidencia de esa fase**, no por presencia de código. Mantener este pendiente mientras T2–T5 o las verificaciones reales sigan abiertos; no borrar documentos sin autorización.
