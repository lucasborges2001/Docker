# Docker Watch: despliegue compartido en ~/servidor/

Estado del piloto físico (evidencia aportada por el operador el **26/10/2026**):
**Boot y Docker migrados y con cutover ejecutado** en
`/home/tecnicosfivisa/servidor` del host `192.168.1.90`.
Es una fotografía fechada, **no** una inspección del host por este documento
ni una aprobación para instalar el siguiente SHA. La fuente versionada
puede evolucionar sin que cambie el release activo.

`scripts/server/install.sh` mantiene la política legacy de `/opt` y sus
bloqueos. El layout nuevo se empaqueta y renderiza separadamente; este
documento no autoriza ni ejecuta instalaciones.

## Objetivo y ownership

La raíz de esta modalidad es /home/<account>/servidor, con SHAs independientes:

- releases/base/<SHA>/ y current/base;
- releases/docker/<SHA>/ y current/docker;
- config/docker/server.env, secreto local fuera del paquete;
- state/docker/reports/, state/docker/incidents/ y logs/docker/;
- systemd/docker-watch*, artefactos revisables antes de su registro;
- reports/docker/, publicación sanitizada aún pendiente de implementar;
- packages/ y manifests/ para paquete, checksum, baseline y rollback.

Las unidades activas de systemd se registran en /etc/systemd/system tras un
cutover explícito; el código y el estado permanecen dentro de ~/servidor/.

## Generación read-only de unidades

Desde el checkout Docker:

```bash
for unit in docker-watch.service docker-watch-telemetry.service \
            docker-watch-heartbeat.service docker-watch-heartbeat.timer; do
  python3 -B scripts/server/render-servidor-units.py \
    --root /home/tecnicosfivisa/servidor --unit "$unit"
done
bash test/shell/docker_servidor_units_test.sh
```

El renderizador únicamente imprime unidades. No escribe en servidor/, no
llama a Docker, no inicia servicios, no toca credenciales y no instala paquetes.

## Paquete local fijado por SHA (sin despliegue)

El ejemplo específico es `config/servidor.env.example`. No reutilizar
`config/server.env.example` legacy ni incluir el `config/docker/server.env`
privado en el release.

Desde un checkout limpio del SHA propietario:

```bash
bash test/shell/docker_servidor_env_example_test.sh
bash test/shell/docker_servidor_package_test.sh
bash scripts/server/package-servidor.sh
```

Se generan `dist/servidor/docker/<SHA>/docker-servidor-<SHA>.tar.gz` y
`docker-servidor-<SHA>.manifest.json`, con `source_sha`,
`source_tree_sha`, `payload_paths` y `archive_sha256`. La selección
positiva se hace a partir de blobs Git, no de directorios locales: quedan
fuera `.env`, reportes, estado y credenciales, incluso con nombres nuevos.
Base se resuelve como release independiente. Este comando no instala units,
no conecta con Docker y no envía Telegram.

Antes de cualquier consumo, comprobar checksum, paths, SHA aprobado, ACL de
`dockwatch`, ubicación privada de `config/docker/server.env` y rollback.

## Evidencia del cutover del 26/10/2026 (no extrapolable a futuros SHAs)

Fuente: salidas de terminal del operador; **no** ejecución propia desde este
checkout. En ese instante:

- Base `01969a16705dbb801868da2ca5e1594fcea2fe92`, referenciado por
  `current/base`, y Docker `2927279f2368cc49705669cfa2b01ee862df012e`,
  referenciado por `current/docker`.
- Artefacto Docker original: SHA-256
  `9fa2dbd8611635c14d048ded5f5ec25dbabe9888a91d3dfc3bc32f1110aac93f`,
  con 15 archivos; **no** es el checksum de los commits posteriores.
- Watcher `docker-watch.service` activo como `dockwatch`; telemetría
  `docker-watch-telemetry.service` activa y produciendo snapshots en
  `state/docker/reports/`; heartbeat bajo timer diario `09:05 -03`.
  La ejecución explícita de heartbeat finalizó `Result=success` y
  `ExecMainStatus=0` el 26/10 a las 12:59:36 -03.
- `dockwatch` pertenece al grupo `docker`, con acceso al Engine 29.5.2.
  **Ese grupo tiene privilegios equivalentes a root**: no dar ese acceso a
  PHP ni agregar miembros automáticamente.
- `config/docker/server.env` es `root`/`0600`; en la muestra
  `SEND_TELEGRAM=false`. No registrar ni importar su contenido privado.
- Smoke de telemetría: `schema_version=2`, `owner=dockwatch`,
  `severity=ok`, sin errores, engine accesible; 16 contenedores totales
  y 9 monitoreados **solo en esa muestra**.
- Operador registró `DOCKER_CUTOVER_PASS`, cuatro unidades principales
  activas (incluido `boot-report.timer`) y cero unidades fallidas
  en la consulta puntual. Backup legacy:
  `~/servidor/manifests/docker-cutover-20261026T155639Z/`.

Las unidades activas se registraron en `/etc/systemd/system/` y se deben
administrar como archivos controlados por root. Los archivos renderizados
bajo `servidor/systemd/` son **staging**, no targets para `systemctl link`
a rutas modificables del HOME. El collector, releases, estado y logs siguen
bajo `~/servidor/` (no es un repositorio Git).

**No demostrado:** reboot, estabilidad indefinida, publicación HTTP
autenticada/read-only, Telegram efectivo, otro host, rollback real de
unidades o ejecución de un SHA nuevo. Un rollout posterior requiere paquete
verificado, smoke opt-in, ventana autorizada, backup/plan de rollback y
comprobación de las unidades desplegadas. El código Git no modifica
`current/docker` por sí mismo.

## Gates previos al cutover

1. Fijar SHAs de Base y Docker; comprobar que los binarios usan BASE_DIR
   apuntando a current/base, sin instalar una dependencia paralela en /opt.
2. El archivo privado `config/docker/server.env` es obligatorio para iniciar
   las tres unidades de servicio nuevas (`EnvironmentFile` sin prefijo `-`).
   Debe apuntar a `state/docker` y `logs/docker` para todas las salidas.
   Su existencia no certifica valores ni precedencia de carga: revisar también
   archivos de entorno residuales; no importar `.env` legacy al paquete o Git.
3. Verificar con la identidad dockwatch el acceso efectivo a current/base,
   current/docker, config, state y logs. ProtectHome=read-only **no** concede
   permisos DAC. Conceder exclusivamente travesía/lectura necesaria, nunca
   chmod 777 ni acceso del PHP al socket.
4. Resolver y auditar acceso al daemon Docker: membresía en grupo docker
   confiere privilegios equivalentes a root sobre el host. No añadir grupos
   automáticamente ni cambiar User a root como atajo.
5. Comprobar que watcher, telemetry y heartbeat tienen salidas separadas,
   evitar doble alerta Telegram y verificar JSON v2 fresco en intervalos
   sucesivos; no confundir procesos running con health aplicativo.
6. Respaldar unidades, código, .env y datos legacy; verificar
   systemd-analyze verify y tests de regresión antes de activar. Documentar
   rollback. No ejecutar los uninstallers legacy ni purgar datos en F2.

La operación de publicar un subset sanitizado para Riegos es un corte
independiente. El renderizador no demuestra instalación, ACL, runtime ni
retención.
