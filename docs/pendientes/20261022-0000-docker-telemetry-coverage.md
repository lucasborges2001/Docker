# Pendiente P1/P2 — Cobertura de métricas y validación Docker real

## Baseline y evidencia

- Docker/main `a668b4ca15cc11093de23e1d21ac93d1d4c8aee2`:
  telemetría v2, counter rates, API container-trend, historia optimizada,
  writable layer opt-in y doctor de capacidad. CI PASS:
  https://github.com/lucasborges2001/Docker/actions/runs/39875681359
- Base main observada: `ac623f037aa1a9d1e605df5a670c426596d922ac`.
  `bin/base-script-timing.py` es reusable, pero el Base fijado en Pruebas
  puede ser anterior. No duplicar timing/reporting.
- Gitlink Docker observado en Pruebas/main:
  `435f9cebe1d8d8067a32a18c64de7f31040c2986`.

## Capacidades implementadas aún no validadas en runtime

- `public_html/api/container-trend.php`: tasas network RX/TX y block I/O
  en muestras compatibles; pruebas unitarias sin daemon.
- `DOCKER_TELEMETRY_STORAGE_ENABLED=false`: sólo al habilitarlo se añade
  `--size` al comando `docker inspect`; se registran `writable_layer_bytes`
  y `rootfs_bytes`. No interpretar `rootfs_bytes` como uso exclusivo.
- `--retention`: estima horizonte por cantidad y tamaño de snapshot.
  No garantiza 30 días si el límite de bytes o los tamaños varían.

## Gaps reales

1. **P1 storage**: no se calcula crecimiento de volúmenes, imágenes ni logs.
   Prohibido sumar tamaños compartidos como si fueran exclusivos.
2. **P1 carga/consistencia**: medir costo de `inspect --size` en Docker
   real, con timeout, 200 contenedores y permisos rootless.
3. **P1 historia**: comprobar gran volumen, expiración y consumo del filesystem;
   evaluar agregación/downsampling antes de subir el límite de bytes.
4. **P1 HTTP/seguridad**: smoke con Base y host real; GET/405/headers,
   autenticación del host, ausencia de secretos y rutas internas en todos
   los endpoints. El test estático no sustituye esta prueba.
5. **P2 alertas**: no existen umbrales validados de crecimiento de RAM,
   writable layer o tasas de red. Diseñar criterios con histéresis y
   supresión de alertas duplicadas antes de conectar Telegram.
6. **P2 integración**: actualizar gitlink sólo con fase autorizada en Pruebas;
   TestKit debe probar el SHA exacto y publicar evidencia del producto.

## Pruebas / criterio de cierre

```bash
python3 -m unittest discover -s test/python -p '*storage_collector_test.py' -v
php test/php/DockerCounterRateTest.php
php test/php/DockerTrendBuilderTest.php
php test/php/DockerHistoryFilesTest.php
BASE_DIR=../Base bash scripts/dev/smoke.sh
python3 scripts/server/installation-doctor.py --deployment --retention
# Sólo en servidor autorizado, después del cutover:
python3 scripts/server/installation-doctor.py --runtime --timeout 10
```

- PASS limitado: fixtures y smokes deterministas para el SHA exacto.
- PASS producto: snapshot nuevo generado desde Docker real, counters
  verificables, recreación/reset, API HTTP y permisos, retención medida,
  overhead aceptable, sin rutas/secretos en JSON, sin autorestart.
- FAIL: lectura engañosa, contadores negativos, falsa salud, pérdida de
  snapshots, filtración, alertas duplicadas o cambio no autorizado del engine.
- No cerrar por CI PASS si la validación de producto sigue pendiente.
