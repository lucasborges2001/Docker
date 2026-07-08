# Cambio — baseline documental Docker docs — 2026-07-08

## Resumen

Se crea una baseline documental completa para `Docker/docs` con el estilo operativo de `Pruebas/docs`.

## Motivo

El auditor estructural reportaba errores por documentación requerida faltante:

```txt
docs/checklists/auditoria-modularidad-modulo.md
docs/contrato-host-modulo.md
docs/estructura-modulo.md
```

## Archivos agregados

```txt
docs/README.md
docs/estructura-modulo.md
docs/contrato-host-modulo.md
docs/checklists/README.md
docs/checklists/auditoria-modularidad-modulo.md
docs/operacion/README.md
docs/operacion/docker-watch.md
docs/auditorias/README.md
docs/auditorias/2026-07-08-docker-watch.md
docs/cambios/README.md
docs/cambios/2026-07-08-docker-docs-baseline.md
docs/pendientes/README.md
docs/pendientes/20260708-0000-docker-api-contracts.md
docs/pendientes/20260708-0010-docker-runtime-safety.md
docs/pendientes/20260708-0020-docker-superadmin-product.md
```

## Qué se cerró

- Índice documental del módulo.
- Documento de estructura requerido por auditor.
- Contrato host-módulo requerido por auditor.
- Checklist de modularidad requerido por auditor.
- Auditoría inicial del estado actual.
- Operación base de watcher/heartbeat/API/SuperAdmin.
- Pendientes vivos priorizados.

## Qué no se modificó

- Runtime PHP.
- Runtime Bash.
- APIs.
- SuperAdmin.
- Scripts server.
- `.env`.
- `.gitignore`.
- `README.md` raíz.
- Punteros de submódulo.
- Host `Pruebas`.

## Resultado esperado

Después de reemplazar `docs/` y ejecutar:

```bash
cd ~/dev/Pruebas
bash scripts/quality/audit_structure.sh submodules/Docker
```

Deberían desaparecer los 3 errores documentales. Los warnings técnicos restantes quedan documentados en pendientes.
