# Pendiente P1 — Docker API JSON contracts y method guards

## Qué falta

Endurecer los endpoints API públicos y de SuperAdmin para que tengan contrato HTTP/JSON explícito.

Rutas candidatas:

```txt
public_html/api/health.php
public_html/api/latest.php
public_html/api/history.php
public_html/api/events.php
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
public_html/superadmin/support/api.php
```

## Evidencia revisada

El auditor reportó:

- `API_COMMON_MISSING` en endpoints bajo `public_html/api` y `public_html/superadmin/api`;
- `API_METHOD_GUARD_MISSING`;
- `API_JSON_CONTRACT_WEAK` en endpoints de SuperAdmin;
- headers PHP faltantes;
- `declare(strict_types=1)` faltante en algunos endpoints SuperAdmin.

Los endpoints revisados devuelven JSON, pero lo hacen de forma compacta y sin frontera HTTP común.

## Riesgo si no se hace

- Contratos difíciles de consumir desde front o host.
- Status HTTP inconsistentes.
- Métodos no permitidos sin `405` + `Allow`.
- Errores visibles como HTML/texto si aparece una excepción o warning PHP.
- Auditor estructural mantiene warnings en cascada.

## Ruta sugerida

### Fase A — helper común

Crear:

```txt
public_html/api/_common.php
```

y/o fortalecer:

```txt
public_html/superadmin/support/api.php
```

Responsabilidades:

- `declare(strict_types=1)`;
- header JSON;
- method guard;
- función `docker_api_json_success()`;
- función `docker_api_json_error()`;
- shape estable.

### Fase B — shape estable

Formato recomendado:

```json
{
  "ok": true,
  "code": "docker.latest.ok",
  "module": "docker",
  "data": {},
  "error": null
}
```

Errores:

```json
{
  "ok": false,
  "code": "docker.snapshot_missing",
  "module": "docker",
  "data": {},
  "error": {
    "message": "No existe snapshot Docker"
  }
}
```

### Fase C — smokes

Agregar tests que validen:

- `GET` permitido;
- `POST` devuelve `405` + `Allow: GET`;
- JSON parseable;
- claves `ok`, `code`, `module`, `data`, `error`;
- fallback sin snapshot;
- límite de `history/events` acotado.

## Verificación reproducible

```bash
cd ~/dev/Pruebas/submodules/Docker
find public_html -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh

cd ~/dev/Pruebas
bash scripts/quality/audit_structure.sh submodules/Docker
```

## Criterio de cierre

- No aparecen `API_COMMON_MISSING`, `API_METHOD_GUARD_MISSING` ni `API_JSON_CONTRACT_WEAK` para endpoints Docker.
- Smokes API pasan.
- Todas las respuestas son JSON parseable.
- Métodos no permitidos devuelven `405` con `Allow` correcto.
- No se agregan acciones destructivas.
