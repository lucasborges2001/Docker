# Cambio — Docker telemetry v2 — 2026-07-24

## Baseline

```text
Repositorio: lucasborges2001/Docker
Rama: main
Commit base: ff3a7ebab7db6ba16b7d75f3dd92ba2a8b8c39e9
```

No se modificaron `Pruebas`, `Base`, `Boot`, `securityLab` ni el gitlink del submódulo.

## Objetivo

Consolidar en Docker la telemetría del engine y sus contenedores, manteniendo eventos, heartbeat, incidentes, historial propio y política de no autorestart.

## Implementado

### Recolección

- collector Docker CLI con timeout;
- fixtures sin daemon;
- CPU, memoria, network I/O, block I/O, PIDs, restart count, health, estado y uptime;
- metadata Compose acotada;
- selección `MONITOR_LABEL ∪ DOCKER_TELEMETRY_ALLOWLIST`;
- límite máximo de contenedores;
- degradación estructurada cuando el engine no está disponible.

### Contrato

- `schema_version=2` expand-only;
- fixture y normalización compatible con snapshot v1;
- `container_ref` sanitizado;
- `instance_ref` opaco para detectar recreate/counter reset;
- agregados y tops por recursos;
- eliminación del path del socket, labels, IDs completos e inspect desde API.

### Persistencia

- escrituras de snapshot mediante archivo temporal y rename;
- latest e historial;
- retención por días, cantidad y tamaño;
- events JSONL con rotación separada por tamaño/cantidad;
- pruning limitado a directorios timestamp bajo reports.

### API y SuperAdmin

- endpoints resources y container detail;
- method guard GET/405;
- `Cache-Control: no-store`;
- tabla read-only por contenedor;
- agregados y tendencias históricas;
- documentación local `public_html/superadmin/dockerFront.md`;
- ausencia de acciones start/stop/restart/kill/exec/recreate.

### Operación

- `bin/docker-telemetry --once|--loop`;
- `docker-watch-telemetry.service`;
- instalación server actualizada;
- servicio capaz de degradar sin requerir que Docker esté activo al iniciar.

### Calidad

- fixtures para recursos, engine ausente, counter reset y snapshot v1;
- tests de sanitización, agregados, lookup y unión label/allowlist;
- workflow de lint PHP/Bash/Python, fixtures y frontera web read-only.

## Compatibilidad

No se aplicó un envelope obligatorio `ok/code/data/error` a todos los endpoints porque eso cambiaría la forma actual de `latest`, `history` y `events`. Esa migración debe diseñarse como contrato versionado o endpoint nuevo.

## Validación final ejecutada localmente

Se reconstruyeron los artefactos finales relevantes y se ejecutó:

```text
python3 -m py_compile collector + runner: PASS
bash test/shell/docker_telemetry_collector_test.sh: PASS
fixture telemetry_mixed: PASS
fixture engine absent: PASS
unión label/allowlist: PASS
counter reset incompatible -> rate null: PASS
bash -n collect.sh: PASS
bash -n persist.sh: PASS
bash -n bin/docker-telemetry: PASS
php -l contracts/normalizer/summary/service: PASS
```

El workflow `.github/workflows/quality.yml` está versionado para ejecutar estas validaciones sobre GitHub. Su ejecución remota no fue confirmada desde el conector, por lo que no se declara CI verde.

## No verificado

- daemon Docker real;
- Docker rootless real;
- Docker Desktop real;
- instalación systemd real;
- smoke completo `BASE_DIR=../Base bash scripts/dev/smoke.sh` sobre el HEAD remoto;
- render HTTP real de SuperAdmin;
- integración y panel agregado en `Pruebas`;
- actualización del gitlink.

## Rollback

El rollback de código es revertir los commits posteriores al baseline en orden inverso. Antes de deshabilitar runtime:

```bash
sudo systemctl disable --now docker-watch-telemetry.service
```

Los snapshots v2 son expand-only; conservarlos no ejecuta acciones sobre Docker.

## Próxima fase

En `Pruebas`, mediante cambio separado:

1. actualizar el gitlink de `submodules/Docker`;
2. consumir contratos públicos;
3. agregar smoke con fixture v2;
4. validar comportamiento sin daemon;
5. verificar resumen agregado `Boot + Docker` sin duplicar collectors.
