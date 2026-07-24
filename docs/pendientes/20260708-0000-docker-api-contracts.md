# Pendiente P1 — Docker API JSON contracts y method guards

## Estado

**Parcialmente resuelto el 2026-07-24.**

La frontera HTTP read-only y la sanitización están implementadas. Permanece abierta únicamente la decisión de migrar a un envelope uniforme `ok/code/data/error` sin romper consumidores existentes.

## Implementado

- `public_html/api/_common.php`;
- helper común de SuperAdmin fortalecido;
- solo método `GET`;
- `405` con `Allow: GET`;
- `Content-Type: application/json`;
- `Cache-Control: no-store`;
- `X-Content-Type-Options: nosniff`;
- endpoints read-only para resources y container detail;
- sanitización de socket, IDs, labels e inspect;
- workflow que verifica sintaxis y ausencia de comandos mutantes en web/backend.

Rutas cubiertas:

```text
public_html/api/health.php
public_html/api/latest.php
public_html/api/history.php
public_html/api/events.php
public_html/api/resources.php
public_html/api/container.php
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
public_html/superadmin/api/resources.php
public_html/superadmin/api/container.php
```

## Decisión de compatibilidad

No se envolvieron las respuestas existentes obligatoriamente en:

```json
{
  "ok": true,
  "code": "docker.latest.ok",
  "module": "docker",
  "data": {},
  "error": null
}
```

Cambiar `latest`, `history` y `events` a ese shape rompería consumidores actuales. La alternativa correcta es una de estas:

1. endpoints `/v2/` con envelope;
2. negociación explícita de versión;
3. migración coordinada con `Pruebas` y consumidores inventariados.

Hasta esa decisión, el contrato actual evoluciona expand-only.

## Evidencia

```text
public_html/api/_common.php
public_html/superadmin/support/api.php
back/metrics/DockerSnapshotNormalizer.php
.github/workflows/quality.yml
test/php/DockerSnapshotNormalizerTest.php
```

## Validación reproducible

```bash
find public_html -type f -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh

grep -RInE \
  --include='*.php' --include='*.js' \
  'docker[[:space:]]+(start|stop|restart|kill|exec|rm|rmi)|shell_exec|exec\(|system\(|passthru|proc_open|popen' \
  public_html back || true
```

## Criterio de cierre restante

- inventariar consumidores actuales;
- decidir estrategia de versionado del envelope;
- agregar smoke HTTP que ejecute GET y POST contra endpoints reales;
- confirmar CI y smoke con `Base`.

No se requieren cambios adicionales para la telemetría v2 ni para mantener la frontera read-only.
