# Pendientes

Pendientes operativos y técnicos vivos del submódulo `Docker`.

## Estado de esta carpeta

Esta carpeta consolida pendientes después de la auditoría documental del 2026-07-08.

La lista usa nombres con formato:

```txt
YYYYMMDD-HHMM-<slug>.md
```

## Índice ordenado

| Archivo | Área | Prioridad | Estado |
|---|---|---|---|
| [`20260708-0000-docker-api-contracts.md`](20260708-0000-docker-api-contracts.md) | API pública/SuperAdmin | P1 | Abierto. |
| [`20260708-0010-docker-runtime-safety.md`](20260708-0010-docker-runtime-safety.md) | Server scripts/runtime safety | P1 | Abierto. |
| [`20260708-0020-docker-superadmin-product.md`](20260708-0020-docker-superadmin-product.md) | SuperAdmin/producto | P2 | Abierto. |

## Criterio usado

Un pendiente queda abierto si cumple al menos una condición:

- falta contrato vivo;
- falta smoke o suite declarada;
- hay warning estructural con riesgo operativo real;
- hay deuda técnica mecánica masiva;
- hay oportunidad clara de producto read-only;
- requiere validación local antes de implementarse.

## Regla

No usar esta carpeta como depósito de prompts largos. Cada pendiente debe declarar:

- qué falta;
- evidencia revisada;
- riesgo si no se hace;
- ruta sugerida;
- verificación reproducible;
- criterio de cierre.
