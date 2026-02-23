#!/usr/bin/env bash
set -euo pipefail

# lib/render.sh

render_alert_die() {
  # args: host ts name exit_code
  local host="$1" ts="$2" name="$3" exit_code="$4"

  cat <<HTML
<b>🔴 DOCKER ALERTA</b>
<i>${host} | ${ts}</i>

<b>Evento</b>
• <b>die</b> — exit code: <b>${exit_code}</b>

<b>Contenedor</b>
<pre>${name}</pre>

<b>🔎 Diagnóstico</b>
<pre>docker ps -a
systemctl status docker-watch.service --no-pager</pre>

<b>Acción sugerida</b>
<pre>docker logs --tail 120 ${name}
docker inspect ${name} | head -c 2000</pre>
HTML
}

render_alert_unhealthy() {
  # args: host ts name
  local host="$1" ts="$2" name="$3"

  cat <<HTML
<b>🟠 DOCKER ALERTA</b>
<i>${host} | ${ts}</i>

<b>Evento</b>
• <b>unhealthy</b>

<b>Contenedor</b>
<pre>${name}</pre>

<b>🔎 Diagnóstico</b>
<pre>docker ps -a
systemctl status docker-watch.service --no-pager</pre>

<b>Acción sugerida</b>
<pre>docker inspect ${name} --format '{{json .State.Health}}'
docker logs --tail 120 ${name}</pre>
HTML
}
