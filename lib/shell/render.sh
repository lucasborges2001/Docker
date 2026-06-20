#!/usr/bin/env bash
if [[ -n "${DOCKER_RENDER_SH_INCLUDED:-}" ]]; then return 0 2>/dev/null || exit 0; fi
DOCKER_RENDER_SH_INCLUDED=1
docker_render_incident_telegram_html() {
  local e="${1:?}" type sev name image msg
  type="$(base_json_get_string "$e" type 2>/dev/null || echo unknown)"; sev="$(base_json_get_string "$e" severity 2>/dev/null || echo unknown)"
  name="$(base_json_get_string "$e" container_name 2>/dev/null || echo unknown)"; image="$(base_json_get_string "$e" image 2>/dev/null || echo unknown)"; msg="$(base_json_get_string "$e" message 2>/dev/null || true)"
  printf '<b>Docker incidente</b>\nTipo: %s\nSeveridad: %s\nContenedor: %s\nImagen: %s\nMensaje: %s\n' "$(base_telegram_escape_html "$type")" "$(base_telegram_escape_html "$sev")" "$(base_telegram_escape_html "$name")" "$(base_telegram_escape_html "$image")" "$(base_telegram_escape_html "$msg")"
}
docker_render_heartbeat_telegram_html() {
  local j="${1:?}" summary engine version running stopped unhealthy monitored open
  summary="$(base_json_get_string "$j" status.summary 2>/dev/null || echo 'Sin resumen')"; engine="$(base_json_get_string "$j" engine.available 2>/dev/null || echo false)"; version="$(base_json_get_string "$j" engine.version 2>/dev/null || true)"
  running="$(base_json_get_number "$j" containers.running 2>/dev/null || echo 0)"; stopped="$(base_json_get_number "$j" containers.stopped 2>/dev/null || echo 0)"; unhealthy="$(base_json_get_number "$j" containers.unhealthy 2>/dev/null || echo 0)"; monitored="$(base_json_get_number "$j" containers.monitored 2>/dev/null || echo 0)"; open="$(base_json_get_number "$j" incidents.open 2>/dev/null || echo 0)"
  printf '<b>Docker heartbeat</b>\nEstado: %s\nEngine: %s %s\nContenedores: %s running / %s stopped / %s unhealthy\nMonitoreados: %s\nIncidentes abiertos: %s\n' "$(base_telegram_escape_html "$summary")" "$(base_telegram_escape_html "$engine")" "$(base_telegram_escape_html "$version")" "$running" "$stopped" "$unhealthy" "$monitored" "$open"
}
docker_render_summary_text() {
  local j="${1:?}" summary generated running stopped unhealthy monitored open
  summary="$(base_json_get_string "$j" status.summary 2>/dev/null || echo 'Sin resumen')"; generated="$(base_json_get_string "$j" generated_at 2>/dev/null || true)"
  running="$(base_json_get_number "$j" containers.running 2>/dev/null || echo 0)"; stopped="$(base_json_get_number "$j" containers.stopped 2>/dev/null || echo 0)"; unhealthy="$(base_json_get_number "$j" containers.unhealthy 2>/dev/null || echo 0)"; monitored="$(base_json_get_number "$j" containers.monitored 2>/dev/null || echo 0)"; open="$(base_json_get_number "$j" incidents.open 2>/dev/null || echo 0)"
  printf 'Docker: %s\nGenerated: %s\nContainers: %s running, %s stopped, %s unhealthy, %s monitored\nOpen incidents: %s\n' "$summary" "$generated" "$running" "$stopped" "$unhealthy" "$monitored" "$open"
}
