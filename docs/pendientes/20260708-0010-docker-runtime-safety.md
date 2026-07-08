# Pendiente P1 — Docker runtime safety para scripts server

## Qué falta

Endurecer scripts server, especialmente `scripts/server/uninstall.sh`, para evitar borrados inseguros.

## Evidencia revisada

El auditor reportó:

```txt
SH_UNGUARDED_RM_RF :: scripts/server/uninstall.sh
```

El script actual elimina rutas como:

```txt
/opt/docker-watch
/var/lib/docker-watch
/var/log/docker-watch
/etc/docker-watch
```

## Riesgo si no se hace

- Borrado accidental de datos runtime.
- Falta de dry-run o confirmación fuerte.
- Dificultad para auditar qué se eliminó.
- Riesgo mayor si en una fase futura se parametrizan rutas.

## Ruta sugerida

### Fase A — helper seguro

Agregar helper Bash local, por ejemplo:

```bash
docker_safe_rm_rf() {
  local target="${1:-}"
  case "$target" in
    ""|"/"|"/var"|"/var/"|"/opt"|"/opt/"|"/etc"|"/etc/")
      echo "Refusing unsafe path: $target" >&2
      return 64
      ;;
  esac
  rm -rf -- "$target"
}
```

Ajustar a la convención real del proyecto y evitar falsos positivos.

### Fase B — modo dry-run

Soportar:

```bash
DRY_RUN=true scripts/server/uninstall.sh
```

Debe imprimir acciones sin borrar.

### Fase C — smoke textual y funcional

Agregar test que valide:

- rechaza vacío;
- rechaza `/`;
- rechaza `/var`, `/opt`, `/etc`;
- solo borra rutas esperadas;
- `PURGE_DATA=false` conserva datos;
- `PURGE_DATA=true` borra solo allowlist.

## Verificación reproducible

```bash
cd ~/dev/Pruebas/submodules/Docker
bash -n scripts/server/uninstall.sh
BASE_DIR=../Base bash scripts/dev/smoke.sh

cd ~/dev/Pruebas
bash scripts/quality/audit_structure.sh submodules/Docker
```

## Criterio de cierre

- El auditor no reporta `SH_UNGUARDED_RM_RF` para `scripts/server/uninstall.sh`.
- Existe smoke de safety.
- El script rechaza rutas peligrosas.
- `PURGE_DATA` queda documentado.
- No se agregan acciones destructivas a UI/API.
