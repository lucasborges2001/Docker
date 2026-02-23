#!/usr/bin/env bash
set -euo pipefail

# lib/telegram.sh (estilo Boot)
# Responsabilidad: hablar con Telegram (send/edit) + utilidades de escape.

: "${BOT_TOKEN:?Falta BOT_TOKEN (env)}"
: "${CHAT_ID:?Falta CHAT_ID (env)}"

TG_PARSE_MODE="${TG_PARSE_MODE:-HTML}"
TG_DISABLE_WEB_PAGE_PREVIEW="${TG_DISABLE_WEB_PAGE_PREVIEW:-true}"

_tg_retry_curl() {
  local tries=5 delay=1 i
  for i in $(seq 1 "$tries"); do
    if "$@"; then return 0; fi
    sleep "$delay"
    delay=$((delay * 2))
  done
  return 1
}

tg_escape_html() {
  local s="${1:-}"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  echo "$s"
}

_tg_check_ok_and_get() {
  local path="$1"
  python3 -c '
import json,sys
p=sys.argv[1]
raw=sys.stdin.read()
try:
    d=json.loads(raw)
except Exception as e:
    print(f"INVALID_JSON: {e}", file=sys.stderr)
    print("RAW_HEAD:", raw[:200].replace("\n","\\n"), file=sys.stderr)
    sys.exit(2)

if not d.get("ok"):
    print(raw, file=sys.stderr)
    sys.exit(1)

cur=d
for part in p.split("."):
    if isinstance(cur, dict) and part in cur:
        cur=cur[part]
    else:
        print(f"MISSING_PATH: {p}", file=sys.stderr)
        sys.exit(3)

print(cur)
' "$path"
}

_tg_api_post() {
  local method="$1"; shift
  local resp
  resp="$(_tg_retry_curl curl -fsS --connect-timeout 8 --max-time 25 -X POST \
    "https://api.telegram.org/bot${BOT_TOKEN}/${method}" "$@")" || return 1
  echo "$resp"
}

tg_send_message() {
  local text="$1"
  local reply_to="${2:-}"

  local args=(
    -d "chat_id=${CHAT_ID}"
    -d "parse_mode=${TG_PARSE_MODE}"
    -d "disable_web_page_preview=${TG_DISABLE_WEB_PAGE_PREVIEW}"
    --data-urlencode "text=${text}"
  )

  if [[ -n "$reply_to" ]]; then
    args+=( -d "reply_to_message_id=${reply_to}" )
  fi

  local resp
  resp="$(_tg_api_post sendMessage "${args[@]}")" || {
    echo "ERROR: Telegram sendMessage failed" >&2
    return 1
  }

  echo "$resp" | _tg_check_ok_and_get "result.message_id"
}

tg_edit_message_text() {
  local message_id="$1"
  local text="$2"

  local resp
  resp="$(_tg_api_post editMessageText \
    -d "chat_id=${CHAT_ID}" \
    -d "message_id=${message_id}" \
    -d "parse_mode=${TG_PARSE_MODE}" \
    -d "disable_web_page_preview=${TG_DISABLE_WEB_PAGE_PREVIEW}" \
    --data-urlencode "text=${text}")" || {
      echo "ERROR: Telegram editMessageText failed" >&2
      return 1
    }

  echo "$resp" | _tg_check_ok_and_get "ok" >/dev/null
}
