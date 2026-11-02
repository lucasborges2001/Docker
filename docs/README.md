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

## Estado del código y validación (revisión estática 2026-11-02)

Baseline inspeccionado: `Docker/main@494a8b54851105d11b267359cd0de2c27b5197d2`. Esta tabla describe capacidades **presentes en código**, no aceptación HTTP, despliegue ni ejecución de tests sobre el HEAD.

| Área | Implementación observada | Validación que sigue pendiente |
|---|---|---|
| Watcher, heartbeat e incidentes | CLI y persistencia presentes; recuperación `die → start` con archivado `*.resolved`. | Verificador completo, concurrencia, retención, daemon real y aceptación de incidentes históricos. |
| Telemetría e historial | Snapshot v2, tasas y almacenamiento opcional de capa escribible. | Resets/ausencia parcial, identidad de engine, volúmenes/logs/imágenes, costo y retención real. |
| APIs públicas | `public_html/api/_common.php` impone GET/405, cabeceras JSON y `no-store`. | Autorización externa, compatibilidad de consumidores y smoke HTTP real. |
| SuperAdmin | Página, endpoints read-only y `public_html/superadmin/dockerFront.md` presentes. | Renderizado v1/v2/degradado, sesión/rol y navegación integrados con host. |
| Instalación y uninstall | Preflight, allowlist de rutas, rechazo de symlinks, dry-run por defecto y confirmaciones para borrar. | Fallos parciales, instalación/uninstall/reinstalación y rollback en VM descartable. |
| Validación local | `scripts/dev/verify-local.sh --compact` define 20 grupos de checks offline; CI es manual-only. | Ejecutarlos en checkout limpio y registrar SHA, exit codes y resultados. |

El índice [`pendientes/README.md`](pendientes/README.md) detalla deuda viva, avances, riesgos y criterios de cierre. No eliminar un pendiente por la mera presencia de implementación.

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
