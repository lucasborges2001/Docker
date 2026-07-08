# Contrato host-módulo — `Pruebas` + `Docker`

## Estado contractual

`Docker` está integrado al host `Pruebas` como submódulo opcional de tooling local.

En `.gitmodules` debe existir:

```txt
[submodule "submodules/Docker"]
    path = submodules/Docker
    url = https://github.com/lucasborges2001/Docker.git
    branch = main
```

En `config/submodules.php`, el contrato esperado es:

```txt
name: Docker
path: submodules/Docker
url: https://github.com/lucasborges2001/Docker.git
branch: main
tier: tooling-local
required_for_preflight: false
include_in_app_deploy: false
tooling: true
optional: true
```

## Interpretación

`Docker` no bloquea el preflight general del host y no debe entrar en deploy de aplicación. Es tooling operativo local para servidor/desarrollo.

## Responsabilidades del host `Pruebas`

| Responsabilidad | Estado esperado |
|---|---|
| Declarar el submódulo en `.gitmodules`. | Requerido. |
| Mantener clasificación como tooling opcional. | Requerido. |
| No tratar `Docker` como módulo runtime de app. | Requerido. |
| Ejecutar auditoría estructural cuando se audite el submódulo. | Recomendado. |
| Evitar mezclar runtime artifacts de `Docker` con repo host. | Requerido. |
| Mantener `Base` disponible para smokes y operación local. | Requerido para validar. |

## Responsabilidades del submódulo `Docker`

| Responsabilidad | Estado esperado |
|---|---|
| Resolver `Base` por `BASE_DIR`, vecindad de submódulos o `/opt/base`. | Requerido. |
| Mantener watcher y heartbeat como entrypoints explícitos. | Requerido. |
| Exponer health/latest/history/events solo lectura. | Requerido. |
| No ejecutar mutaciones Docker desde endpoints web. | Requerido. |
| No reiniciar contenedores automáticamente. | Requerido. |
| Mantener fixtures de reportes para UI/smokes. | Recomendado. |
| Documentar cualquier acción destructiva manual en operación server, no en UI. | Requerido. |

## Contrato de dependencia con `Base`

`Docker` consume `Base` pero no debe duplicar helpers comunes.

Dependencias esperadas:

```txt
Base/lib/shell/env.sh
Base/lib/shell/log.sh
Base/lib/shell/json.sh
Base/lib/shell/lock.sh
Base/lib/shell/time.sh
Base/lib/shell/telegram.sh
Base/back/metrics/*
Base/back/telegram/*
```

Contrato práctico:

```bash
cd submodules/Docker
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

## Contrato web/API

Los endpoints pueden devolver estado degradado cuando no hay snapshot real, pero deben hacerlo con JSON estable.

Endpoints esperados:

```txt
public_html/api/health.php
public_html/api/latest.php
public_html/api/history.php
public_html/api/events.php
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
```

Contrato futuro recomendado:

```json
{
  "ok": true,
  "code": "docker.ok",
  "module": "docker",
  "data": {},
  "error": null
}
```

Para errores:

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

## Contrato de seguridad

### Permitido

- Leer reportes.
- Leer eventos JSONL.
- Mostrar status en SuperAdmin.
- Enviar Telegram desde procesos server controlados.
- Ejecutar smokes locales.

### No permitido desde host/web por defecto

- Reiniciar contenedores.
- Borrar contenedores, imágenes, redes o volúmenes.
- Ejecutar `docker compose down`, `docker rm`, `docker rmi`, `docker system prune` desde UI/API.
- Modificar `.env` o systemd desde SuperAdmin.
- Exponer secretos Telegram o rutas sensibles sin sanitización.

## Smoke host recomendado

Agregar en una fase posterior un smoke host que verifique:

1. `.gitmodules` contiene `submodules/Docker`.
2. `config/submodules.php` clasifica `Docker` como `tooling-local`, opcional y fuera de deploy.
3. El submódulo contiene `bin/docker-watch`, `bin/docker-heartbeat` y `scripts/dev/smoke.sh`.
4. No existen botones o endpoints web que ejecuten comandos destructivos.
5. Las APIs devuelven JSON y no texto plano/HTML.

## Comandos de verificación

```bash
cd ~/dev/Pruebas

git status --short
git submodule status --recursive | grep 'submodules/Docker' || true

grep -n 'submodules/Docker' .gitmodules
grep -n "'name' => 'Docker'" -A14 config/submodules.php

bash scripts/quality/audit_structure.sh submodules/Docker

cd submodules/Docker
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

## Criterio de cierre

El contrato se considera sano cuando:

- `Docker` sigue declarado como tooling opcional;
- no bloquea deploy de app;
- el smoke local pasa con `BASE_DIR=../Base`;
- las APIs son read-only y devuelven contrato estable;
- el auditor estructural no reporta errores documentales;
- los warnings técnicos restantes están documentados como pendientes vivos.
