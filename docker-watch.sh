\
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/opt/docker-watch/.env"

log_ok()   { echo "DOCKER_WATCH_OK $*"; }
log_fail() { echo "DOCKER_WATCH_FAIL $*"; }
log_skip() { echo "DOCKER_WATCH_SKIP $*"; }

retry_backoff() {
  local tries="${1:-6}"; shift
  local i=1 delay=1
  while (( i <= tries )); do
    if "$@"; then return 0; fi
    sleep "$delay"
    delay=$((delay*2)); (( delay > 24 )) && delay=24
    i=$((i+1))
  done
  return 1
}

curl_quiet() { curl -fsS --max-time 7 "$@"; }

escape_html() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

emoji() {
  [[ "${DOCKER_EMOJI:-true}" == "true" ]] || { echo ""; return; }
  echo -n "$1"
}

send_telegram() {
  local resp
  resp="$(
    curl -fsS --max-time 12 -X POST \
      "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -d chat_id="${CHAT_ID}" \
      -d parse_mode="HTML" \
      -d disable_web_page_preview="true" \
      --data-urlencode text="${MSG}"
  )" || return 1
  grep -q '"ok"[[:space:]]*:[[:space:]]*true' <<<"$resp"
}

net_ready() {
  ip route get "${NET_CHECK_IP:-1.1.1.1}" >/dev/null 2>&1 || return 1
  getent hosts "${NET_CHECK_DNS:-api.telegram.org}" >/dev/null 2>&1 || return 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log_fail "missing_cmd=$1"; exit 1; }
}

# --------------------------- Load env -------------------------------------

if [[ ! -f "$ENV_FILE" ]]; then
  log_fail "missing_env_file=$ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

: "${BOT_TOKEN:?missing BOT_TOKEN in $ENV_FILE}"
: "${CHAT_ID:?missing CHAT_ID in $ENV_FILE}"
SERVER_LABEL="${SERVER_LABEL:-$(hostname)}"

# ------------------------ Anti-duplicados ---------------------------------

RUNDIR="${DOCKER_WATCH_RUNDIR:-/run/docker-watch}"
LOCK_TTL_SEC="${LOCK_TTL_SEC:-300}"

if [[ ! -d "$RUNDIR" ]]; then
  RUNDIR="/tmp/docker-watch"
  mkdir -p "$RUNDIR"
fi

LOCK_FILE="${RUNDIR}/docker-watch.lock"
STAMP_FILE="${RUNDIR}/docker-watch.stamp"
NOW_EPOCH="$(date +%s)"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log_skip "lock_busy"
  exit 0
fi

if [[ -f "$STAMP_FILE" ]]; then
  read -r last_epoch <"$STAMP_FILE" || true
  last_epoch="${last_epoch:-0}"
  if (( NOW_EPOCH - last_epoch < LOCK_TTL_SEC )); then
    log_skip "within_ttl age=$((NOW_EPOCH-last_epoch))"
    exit 0
  fi
fi

# --------------------------- Prechecks ------------------------------------

require_cmd awk
require_cmd hostname
require_cmd ip
require_cmd curl
require_cmd docker
require_cmd flock
require_cmd getent

# ¿Docker daemon?
if ! docker info >/dev/null 2>&1; then
  MSG="$(
    {
      echo "<b>Docker Watch — ${SERVER_LABEL}</b>"
      echo ""
      echo "<b>Estado</b>"
      echo "<pre>docker: $(emoji "🔴 ")DOWN</pre>"
      echo "<pre>time : $(date -Is)</pre>"
      echo ""
      echo "<pre>hint : systemctl status docker</pre>"
      echo "<pre>hint : journalctl -u docker -b</pre>"
    } | escape_html
  )"

  if retry_backoff 10 net_ready && retry_backoff 6 send_telegram; then
    printf '%s\n' "$NOW_EPOCH" >"$STAMP_FILE"
    chmod 600 "$STAMP_FILE" 2>/dev/null || true
    log_ok "sent docker_down"
    exit 0
  else
    log_fail "send_failed docker_down"
    exit 1
  fi
fi

# --------------------------- Recolección ----------------------------------

IGNORE="${IGNORE_CONTAINERS:-}"
ONLY_PROJECT="${ONLY_THIS_COMPOSE:-}"
RESTART_ON_STOP="${RESTART_ON_STOP:-false}"
RESTART_COOLDOWN_SEC="${RESTART_COOLDOWN_SEC:-600}"

in_csv() {
  local csv="$1" item="$2"
  [[ -z "$csv" ]] && return 1
  IFS=',' read -ra parts <<<"$csv"
  for p in "${parts[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}"
    [[ "$p" == "$item" ]] && return 0
  done
  return 1
}

cooldown_ok() {
  local key="$1"
  local file="${RUNDIR}/restart_${key}.stamp"
  local now="$NOW_EPOCH"
  if [[ -f "$file" ]]; then
    local last; last="$(cat "$file" 2>/dev/null || echo 0)"
    if (( now - last < RESTART_COOLDOWN_SEC )); then
      return 1
    fi
  fi
  echo "$now" >"$file" 2>/dev/null || true
  return 0
}

FILTER_ARGS=()
if [[ -n "$ONLY_PROJECT" ]]; then
  FILTER_ARGS+=(--filter "label=com.docker.compose.project=${ONLY_PROJECT}")
fi

mapfile -t rows < <(docker ps -a "${FILTER_ARGS[@]}" --format '{{.ID}}|{{.Names}}|{{.State}}|{{.Status}}|{{.Image}}')

unhealthy=()
stopped=()
restarting=()
dead=()

for r in "${rows[@]}"; do
  IFS='|' read -r cid name state status image <<<"$r"

  if in_csv "$IGNORE" "$cid" || in_csv "$IGNORE" "$name"; then
    continue
  fi

  health=""
  [[ "$status" == *"(unhealthy)"* ]] && health="unhealthy"
  [[ "$status" == *"(healthy)"* ]] && health="healthy"

  case "$state" in
    running)
      if [[ "${WARN_UNHEALTHY:-true}" == "true" && "$health" == "unhealthy" ]]; then
        unhealthy+=("$name|$cid|$image|$status")
      fi
      ;;
    exited|created)
      stopped+=("$name|$cid|$image|$status")
      ;;
    restarting)
      [[ "${WARN_RESTARTING:-true}" == "true" ]] && restarting+=("$name|$cid|$image|$status")
      ;;
    dead)
      [[ "${WARN_DEAD:-true}" == "true" ]] && dead+=("$name|$cid|$image|$status")
      ;;
  esac
done

restart_actions=()
if [[ "$RESTART_ON_STOP" == "true" && ${#stopped[@]} -gt 0 ]]; then
  for s in "${stopped[@]}"; do
    IFS='|' read -r name cid image status <<<"$s"
    key="${cid:0:12}"
    if cooldown_ok "$key"; then
      if docker restart "$cid" >/dev/null 2>&1; then
        restart_actions+=("$name|$cid|restarted")
      else
        restart_actions+=("$name|$cid|restart_failed")
      fi
    else
      restart_actions+=("$name|$cid|cooldown_skip")
    fi
  done
fi

has_alerts="false"
[[ ${#unhealthy[@]} -gt 0 ]] && has_alerts="true"
[[ ${#stopped[@]} -gt 0 ]] && has_alerts="true"
[[ ${#restarting[@]} -gt 0 ]] && has_alerts="true"
[[ ${#dead[@]} -gt 0 ]] && has_alerts="true"

if [[ "${ALERTS_ONLY:-false}" == "true" && "$has_alerts" != "true" ]]; then
  log_skip "alerts_only_no_alerts"
  exit 0
fi

running_cnt="$(docker ps "${FILTER_ARGS[@]}" --format '{{.ID}}' | wc -l | awk '{print $1}')"
all_cnt="${#rows[@]}"

fmt_list() {
  local title="$1"; shift
  local arr=("$@")
  [[ ${#arr[@]} -eq 0 ]] && return 0
  echo "<b>${title}</b>"
  for x in "${arr[@]}"; do
    IFS='|' read -r name cid image status <<<"$x"
    echo "<pre>- ${name}  (${cid:0:12})</pre>"
    echo "<pre>  img: ${image}</pre>"
    echo "<pre>  st : ${status}</pre>"
  done
  echo ""
}

fmt_actions() {
  [[ ${#restart_actions[@]} -eq 0 ]] && return 0
  echo "<b>Acciones (STOPPED)</b>"
  for x in "${restart_actions[@]}"; do
    IFS='|' read -r name cid action <<<"$x"
    case "$action" in
      restarted)      a="$(emoji "🟢 ")restarted" ;;
      restart_failed) a="$(emoji "🔴 ")restart_failed" ;;
      cooldown_skip)  a="$(emoji "🟠 ")cooldown_skip" ;;
      *)              a="$action" ;;
    esac
    echo "<pre>- ${name}  (${cid:0:12})  ${a}</pre>"
  done
  echo ""
}

MSG="$(
  {
    echo "<b>Docker Watch — ${SERVER_LABEL}</b>"
    echo "<pre>docker : $(emoji "🟢 ")OK</pre>"
    echo "<pre>cnt    : ${running_cnt}/${all_cnt} running</pre>"
    echo "<pre>time   : $(date -Is)</pre>"
    echo ""
    fmt_list "UNHEALTHY" "${unhealthy[@]}"
    fmt_list "STOPPED/EXITED" "${stopped[@]}"
    fmt_list "RESTARTING" "${restarting[@]}"
    fmt_list "DEAD" "${dead[@]}"
    fmt_actions
    if [[ "$RESTART_ON_STOP" != "true" && ${#stopped[@]} -gt 0 ]]; then
      echo "<pre>note: RESTART_ON_STOP=false (solo aviso)</pre>"
    fi
  } | escape_html
)"

if ! retry_backoff 10 net_ready; then
  log_fail "net_not_ready"
  exit 1
fi

if retry_backoff 6 send_telegram; then
  printf '%s\n' "$NOW_EPOCH" >"$STAMP_FILE"
  chmod 600 "$STAMP_FILE" 2>/dev/null || true
  log_ok "sent alerts=$has_alerts"
  exit 0
else
  log_fail "telegram_send_failed"
  exit 1
fi
