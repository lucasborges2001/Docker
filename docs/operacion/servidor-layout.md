# Docker Watch: despliegue compartido en ~/servidor/

Estado: **preparación de integración**, sin instalación ni cutover autorizado.
scripts/server/install.sh conserva su política de /opt y su bloqueo de .env y
unidades legacy. No se ha relajado ninguna protección.

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
