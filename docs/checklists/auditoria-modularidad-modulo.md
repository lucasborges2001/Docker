# Checklist de auditoría de modularidad — `Docker`

## Objetivo

Verificar que `Docker` se mantiene como submódulo modular de observabilidad, dependiente de `Base` para utilidades comunes y sin mezclarse con runtime de aplicación ni acciones destructivas desde UI/API.

## Estado resumido

| Ítem | Estado | Observación |
|---|---|---|
| Documento de estructura | Cubierto | `docs/estructura-modulo.md`. |
| Contrato host-módulo | Cubierto | `docs/contrato-host-modulo.md`. |
| Checklist modularidad | Cubierto | Este documento. |
| Dependencia Base | Parcialmente sano | Se resuelve por `BASE_DIR`, vecindad o `/opt/base`. |
| Runtime propio acotado | Sano | Docker conserva lógica específica de observabilidad. |
| APIs read-only | Parcial | Son read-only por implementación actual, pero falta contrato HTTP común. |
| SuperAdmin | Parcial | Vista compacta, pero falta hardening y doc local. |
| Seguridad uninstall | Pendiente | `rm -rf` requiere guardas. |
| Headers PHP/JS | Pendiente | Warning mecánico amplio. |

## Checklist estructural

### Documentación

- [x] Existe `docs/estructura-modulo.md`.
- [x] Existe `docs/contrato-host-modulo.md`.
- [x] Existe `docs/checklists/auditoria-modularidad-modulo.md`.
- [x] Existe índice `docs/README.md`.
- [x] Existen índices para `auditorias`, `cambios`, `operacion` y `pendientes`.
- [ ] Existe documentación local en `public_html/superadmin/<modulo>Front.md` o equivalente si se quiere cerrar `MODULE_DOC_MISSING`.

### Bootstrap y dependencias

- [x] `back/bootstrap.php` resuelve `Base` por candidatos controlados.
- [x] Shell entrypoints cargan helpers de `Base`.
- [x] La lógica común no está duplicada de forma evidente en la documentación revisada.
- [ ] Evaluar si `back/bootstrap.php` debe mover `require_once` antes de funciones o quedar allowlisteado.

### APIs

- [x] Existen endpoints read-only para `health`, `latest`, `history` y `events`.
- [ ] Agregar `_common.php` o helper común API.
- [ ] Agregar guarda de método HTTP con `405` + `Allow`.
- [ ] Estabilizar shape JSON con `ok`, `code`, `module`, `data`, `error`.
- [ ] Cubrir HTTP status y JSON con smoke.

### SuperAdmin

- [x] Vista modularizada en partials.
- [x] JS mínimo no ejecuta acciones sensibles.
- [ ] Agregar headers `@file/@brief` y `declare(strict_types=1)` donde corresponda.
- [ ] Documentar frontera SuperAdmin en `public_html/superadmin/dockerFront.md` si se mantiene ese patrón del auditor.
- [ ] Evitar botones de mutación Docker desde UI.

### Shell/server

- [x] Entry points usan `set -euo pipefail`.
- [x] Watcher y heartbeat cargan `Base`.
- [ ] Revisar `scripts/server/uninstall.sh` para validar rutas antes de `rm -rf`.
- [ ] Smoke específico para uninstall dry-run o helper seguro.

### Tests

- [x] `scripts/dev/smoke.sh` ejecuta lint PHP y tests PHP/Shell.
- [x] Existen tests PHP mínimos para status/normalización.
- [x] Existe test shell de heartbeat.
- [ ] Agregar smoke de contrato API JSON.
- [ ] Agregar smoke de ausencia de comandos destructivos en `public_html`.
- [ ] Agregar smoke host para clasificación `tooling-local`.

## Prioridades recomendadas

| Prioridad | Acción | Motivo |
|---|---|---|
| P0 | Cerrar errores documentales. | Bloqueaban auditor estructural con errores. |
| P1 | Hardening de API JSON/método/common. | Reduce warnings visibles y estabiliza integración web. |
| P1 | Guardas de uninstall. | Evita riesgo operativo por `rm -rf`. |
| P2 | Headers PHP/JS y strict types. | Cierre mecánico masivo del auditor. |
| P2 | SuperAdmin doc local. | Cierra warning modular y aclara frontera UI. |
| P3 | Mejoras de producto read-only. | Métricas, filtros y export de diagnóstico sin mutación. |

## Comandos sugeridos

```bash
cd ~/dev/Pruebas
bash scripts/quality/audit_structure.sh submodules/Docker

cd submodules/Docker
find . -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

## Criterio de cierre del checklist

Este checklist queda cerrado cuando:

- `audit_structure` no reporta errores documentales;
- cada warning restante tiene pendiente vivo o fix aplicado;
- las APIs tienen contrato común;
- `uninstall.sh` rechaza rutas vacías/raíz y opera con helper seguro;
- SuperAdmin mantiene frontera read-only sin acciones destructivas.
