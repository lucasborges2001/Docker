# Contrato host-módulo — `Pruebas` + `Docker`

## Estado contractual

`Docker` se integra a `Pruebas` como submódulo opcional de tooling local. No forma parte del deploy de aplicación y depende únicamente de `Base`.

```text
Boot = telemetría general del host
Docker = engine, contenedores, recursos, eventos e incidentes Docker
securityLab = señales defensivas e inventario autorizado
Pruebas = wiring, panel agregado y smokes
Base = helpers y contratos reutilizables
```

## Declaración esperada en el host

`.gitmodules`:

```text
[submodule "submodules/Docker"]
    path = submodules/Docker
    url = https://github.com/lucasborges2001/Docker.git
    branch = main
```

`config/submodules.php`:

```text
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

## Responsabilidades de `Pruebas`

- declarar y fijar el gitlink;
- mantener Docker fuera del deploy de aplicación;
- integrar mediante contratos públicos y adapters read-only;
- agregar smokes de composición `Boot + Docker` sin copiar collectors;
- no leer `libexec/`, `lib/shell/`, incidents o archivos internos directamente;
- no ejecutar mutaciones Docker desde el panel agregado.

## Responsabilidades de `Docker`

- resolver `Base` mediante `BASE_DIR`, vecindad o `/opt/base`;
- mantener `bin/docker-watch`, `bin/docker-telemetry` y `bin/docker-heartbeat`;
- recolectar únicamente señales propias del runtime Docker;
- conservar snapshots, events JSONL e incidentes en rutas administradas;
- exponer health, latest, history, events, resources y container detail read-only;
- mantener fixtures sin daemon;
- no autorestart;
- no depender de `Boot`, `securityLab` o `Pruebas`.

## Dependencia con `Base`

```text
Base/lib/shell/env.sh
Base/lib/shell/log.sh
Base/lib/shell/json.sh
Base/lib/shell/lock.sh
Base/lib/shell/time.sh
Base/lib/shell/telegram.sh
Base/back/metrics/*
Base/back/telegram/*
```

Validación:

```bash
cd submodules/Docker
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

## Contrato de snapshot

Versión actual:

```json
{
  "module": "docker",
  "schema_version": 2,
  "schema_compatibility": {
    "minimum": 1,
    "current": 2,
    "mode": "expand-only"
  }
}
```

Los campos v1 permanecen disponibles. Los consumidores deben aceptar versiones mayores o iguales a la mínima soportada y leer campos conocidos, no comparar estrictamente `schema_version === 1`.

`container_ref` es la identidad pública sanitizada. `instance_ref` identifica de forma opaca una instancia y cambia ante recreate; nunca se expone el container ID completo.

## Contrato web/API

Público:

```text
public_html/api/health.php
public_html/api/latest.php
public_html/api/history.php
public_html/api/events.php
public_html/api/resources.php
public_html/api/container.php?container_ref=<ref>
```

SuperAdmin:

```text
public_html/superadmin/api/latest.php
public_html/superadmin/api/history.php
public_html/superadmin/api/events.php
public_html/superadmin/api/probe.php
public_html/superadmin/api/resources.php
public_html/superadmin/api/container.php?container_ref=<ref>
```

Invariantes HTTP:

- solo `GET`;
- `405` y `Allow: GET` para otros métodos;
- JSON UTF-8;
- `Cache-Control: no-store`;
- degradación explícita si no hay snapshot;
- no se acepta un comando Docker por query, body o header.

## Sanitización

API y UI pueden exponer:

- estado y versión del engine;
- `socket_resolved`, nunca el path del socket;
- refs sanitizadas;
- estado, health, recursos y metadata Compose acotada;
- agregados y tendencias.

No pueden exponer:

- env vars o secrets;
- mounts;
- labels completas;
- inspect completo;
- IDs Docker completos;
- logs completos de contenedor.

## Seguridad

Permitido:

- leer snapshots e historial;
- leer eventos e incidentes;
- mostrar recursos;
- enviar Telegram desde procesos server controlados;
- ejecutar smokes locales.

No permitido desde host o web:

```text
docker start
docker stop
docker restart
docker kill
docker exec
docker rm
docker rmi
docker system prune
docker compose down
```

## Integración pendiente en `Pruebas`

Después de publicar y validar Docker:

1. actualizar el gitlink en una fase separada;
2. verificar SHA anterior y nuevo;
3. adaptar el panel agregado a contratos públicos;
4. ejecutar smoke con fixture v2;
5. verificar comportamiento sin daemon;
6. comprobar que `Boot` y `Docker` no duplican ownership.

## Comandos de verificación

```bash
cd ~/dev/Pruebas
git status --short --branch
git submodule status --recursive | grep 'submodules/Docker' || true
bash scripts/quality/audit_structure.sh submodules/Docker

cd submodules/Docker
find . -type f -name '*.php' -print0 | xargs -0 -n1 php -l
python3 -m py_compile libexec/docker-telemetry-collector.py
BASE_DIR=../Base bash scripts/dev/smoke.sh
```

## Criterio de cierre

- `Docker` sigue siendo tooling opcional;
- depende solo de `Base`;
- snapshot v1 sigue normalizando;
- snapshot v2 expone recursos sanitizados;
- APIs y SuperAdmin son read-only;
- no hay autorestart ni ejecución remota;
- fixtures y smokes pasan;
- `Pruebas` consume contratos públicos y valida la integración por separado.
