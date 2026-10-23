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

## Gates previos al cutover

1. Fijar SHAs de Base y Docker; comprobar que los binarios usan BASE_DIR
   apuntando a current/base, sin instalar una dependencia paralela en /opt.
2. El config/docker/server.env privado debe apuntar a state/docker y
   logs/docker para todas las salidas. Evitar importar el .env legacy al
   paquete o a Git.
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
