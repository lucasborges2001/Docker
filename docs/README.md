# Docker Watch · documentación

Documentación operativa y técnica del submódulo `Docker`.

`Docker` es un submódulo de tooling local para observabilidad Docker. Su responsabilidad principal es observar eventos, generar snapshots, persistir historial, exponer APIs read-only y mostrar estado en SuperAdmin sin reiniciar contenedores.

## Índice

| Documento | Propósito |
|---|---|
| [`estructura-modulo.md`](estructura-modulo.md) | Mapa técnico del submódulo, capas, entrypoints, dependencias y fronteras. |
| [`contrato-host-modulo.md`](contrato-host-modulo.md) | Contrato entre `Pruebas`, `Base` y `Docker`. |
| [`operacion/docker-watch.md`](operacion/docker-watch.md) | Guía operativa: watcher, heartbeat, reportes, APIs y validaciones. |
| [`checklists/auditoria-modularidad-modulo.md`](checklists/auditoria-modularidad-modulo.md) | Checklist requerido por el auditor estructural. |
| [`auditorias/`](auditorias/) | Auditorías y diagnósticos cerrados. |
| [`cambios/`](cambios/) | Cambios documentales aplicados. |
| [`pendientes/`](pendientes/) | Pendientes vivos ordenados por prioridad y criterio de cierre. |

## Estado actual

| Área | Estado | Observación |
|---|---|---|
| Runtime watcher | Operable con dependencia de `Base`. | Usa shell helpers de `Base` y lógica específica de Docker. |
| Heartbeat | Operable. | Genera snapshot, summary y evento de heartbeat. |
| APIs públicas | Read-only, pero débiles a nivel contrato HTTP. | Falta `_common.php`, guardas de método y shape JSON más explícito. |
| SuperAdmin | Vista compacta read-only. | Falta documentación local en raíz de `public_html/superadmin` y hardening de endpoints. |
| Documentación estructural | Cubierta por este paquete. | Se agregan los documentos requeridos por `audit_structure`. |
| Seguridad de uninstall | Pendiente. | Hay `rm -rf` sobre rutas absolutas que requiere guardas explícitas. |

## Regla de operación

`Docker` no debe convertirse en orquestador destructivo. La frontera aceptada es:

- observar;
- registrar;
- resumir;
- alertar;
- exponer estado read-only;
- facilitar diagnóstico.

Queda fuera de alcance por defecto:

- reiniciar contenedores;
- borrar volúmenes;
- ejecutar comandos arbitrarios contra Docker;
- hacer pruning desde UI;
- modificar infraestructura desde SuperAdmin.

## Validaciones recomendadas

Desde el host `Pruebas`:

```bash
git status --short
bash scripts/quality/audit_structure.sh submodules/Docker
```

Desde el submódulo:

```bash
cd submodules/Docker
find . -name '*.php' -print0 | xargs -0 -n1 php -l
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

## Criterio documental

Cada pendiente debe declarar:

- qué falta;
- evidencia revisada;
- riesgo si no se hace;
- ruta sugerida;
- verificación reproducible;
- criterio de cierre.
