# Pendiente P2 — Docker SuperAdmin read-only productización

## Qué falta

Convertir la vista SuperAdmin de `Docker` en una pantalla de diagnóstico read-only más útil y alineada con el estilo de Base, sin agregar acciones destructivas.

## Evidencia revisada

Estado actual observado:

```txt
public_html/superadmin/index.php
public_html/superadmin/partials/*
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
public_html/superadmin/assets/docker-superadmin.js
```

El auditor marcó:

- `MODULE_DOC_MISSING :: public_html/superadmin`;
- headers PHP faltantes;
- strict types faltantes;
- wrappers sospechosos;
- contratos JSON débiles;
- JS sin header.

## Riesgo si no se hace

- Pantalla útil pero poco contractuada.
- Warnings estructurales persistentes.
- Riesgo de que futuras mejoras agreguen botones de mutación Docker sin contrato.
- Menor valor de producto frente a otros módulos con SuperAdmin más robusto.

## Ruta sugerida

### Fase A — documentación local del módulo web

Agregar uno de estos documentos, según patrón que prefiera el auditor:

```txt
public_html/superadmin/dockerFront.md
```

o equivalente aceptado por reglas.

Debe declarar:

- propósito;
- rutas API consumidas;
- componentes/partials;
- frontera read-only;
- acciones prohibidas;
- smokes asociados.

### Fase B — UI read-only útil

Agregar sin mutación:

- tarjetas de estado de engine;
- contenedores monitoreados por label;
- últimos eventos filtrables;
- historial de snapshots;
- estado de Telegram sin secretos;
- paths sanitizados;
- copia de comando de validación local;
- badges de severidad.

### Fase C — smokes UI/API

Cubrir:

- no hay formularios POST destructivos;
- no aparecen tokens/comandos peligrosos en UI;
- JS no ejecuta `fetch` hacia endpoints mutantes;
- endpoints devuelven JSON estable;
- fixtures sample permiten render sin Docker real.

## Prohibido en esta fase

No agregar botones para:

```txt
restart
stop
rm
rmi
prune
compose down
volume rm
network rm
```

## Verificación reproducible

```bash
cd ~/dev/Pruebas/submodules/Docker
find public_html -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh

grep -RIn "restart\|stop\|rm\|rmi\|prune\|compose down\|volume rm\|network rm" public_html || true
```

## Criterio de cierre

- Existe doc local para `public_html/superadmin`.
- `MODULE_DOC_MISSING` desaparece.
- La pantalla mejora diagnóstico sin acciones destructivas.
- Las APIs asociadas tienen contrato estable.
- Smokes UI/API pasan.
