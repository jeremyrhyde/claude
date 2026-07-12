# shellcheck shell=sh
# Shared helpers for session-sync. Sourced by the other scripts (never executed directly).
# Provides: config loading, portable Syncthing API-key discovery, REST helpers, and the
# scan / wait-until-synced logic. Intentionally POSIX sh + jq (runs on Linux and macOS).

# --- config -----------------------------------------------------------------
: "${SESSION_SYNC_CONFIG:=$HOME/.config/session-sync/config.sh}"
# shellcheck disable=SC1090
[ -f "$SESSION_SYNC_CONFIG" ] && . "$SESSION_SYNC_CONFIG"
: "${SYNCTHING_URL:=http://127.0.0.1:8384}"
: "${SYNC_WAIT_TIMEOUT:=120}"

die()  { printf 'session-sync: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

require_tools() {
  have curl || die "curl not found"
  have jq   || die "jq not found (Linux: apt install jq · macOS: brew install jq)"
}

# --- Syncthing API key (portable across Linux + macOS) ----------------------
syncthing_config_xml() {
  for c in \
    "$HOME/.local/state/syncthing/config.xml" \
    "$HOME/.config/syncthing/config.xml" \
    "$HOME/Library/Application Support/Syncthing/config.xml"; do
    [ -f "$c" ] && { printf '%s' "$c"; return 0; }
  done
  # last resort: ask syncthing itself where its config lives
  if have syncthing; then
    p=$(syncthing --paths 2>/dev/null | awk -F': *' 'tolower($1) ~ /config/ {print $2; exit}')
    [ -n "$p" ] && [ -d "$p" ] && [ -f "$p/config.xml" ] && { printf '%s' "$p/config.xml"; return 0; }
    [ -n "$p" ] && [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  fi
  return 1
}

syncthing_api_key() {
  [ -n "${SYNCTHING_API_KEY:-}" ] && { printf '%s' "$SYNCTHING_API_KEY"; return 0; }
  xml=$(syncthing_config_xml) || { echo "cannot find Syncthing config.xml; set SYNCTHING_API_KEY in config" >&2; return 1; }
  key=$(tr -d '\n' < "$xml" | sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p')
  [ -n "$key" ] || { echo "no <apikey> found in $xml" >&2; return 1; }
  printf '%s' "$key"
}

# Resolve tools + API key in the MAIN shell (so die() actually exits). Call before any st_*.
st_ready() {
  require_tools
  [ -n "${ST_KEY:-}" ] && return 0
  ST_KEY=$(syncthing_api_key) || die "could not obtain the Syncthing API key"
}
st_get()  { curl -fsS -H "X-API-Key: $ST_KEY" "$SYNCTHING_URL$1"; }
st_post() { curl -fsS -X POST -H "X-API-Key: $ST_KEY" "$SYNCTHING_URL$1"; }

# --- sync operations --------------------------------------------------------
sync_scan() { for id in "$@"; do st_post "/rest/db/scan?folder=$id" >/dev/null 2>&1 || true; done; }

# Block until each given folder is locally idle with nothing left to pull.
sync_wait_folders() {
  st_ready
  sync_scan "$@"
  _start=$(date +%s)
  for id in "$@"; do
    printf 'session-sync: waiting for folder "%s" ' "$id"
    while :; do
      js=$(st_get "/rest/db/status?folder=$id") || die "REST error — is Syncthing running?"
      state=$(printf '%s' "$js" | jq -r '.state // "unknown"')
      need=$(printf '%s' "$js" | jq -r '((.needBytes//0)+(.needItems//0)+(.needDeletes//0))|floor')
      [ "$state" = "idle" ] && [ "$need" -eq 0 ] && { echo "OK"; break; }
      _now=$(date +%s)
      [ $(( _now - _start )) -ge "$SYNC_WAIT_TIMEOUT" ] && { echo; die "timeout on \"$id\" (state=$state, need=$need)"; }
      printf '.'; sleep 2
    done
  done
  echo "session-sync: up to date."
}

# Push side: rescan, then (optionally) wait for a configured, online peer to receive it all.
sync_push_folders() {
  st_ready
  for id in "$@"; do
    st_post "/rest/db/scan?folder=$id" >/dev/null || die "rescan failed for \"$id\" — is Syncthing running?"
    echo "session-sync: rescanned \"$id\""
  done
  if [ -z "${PEER_DEVICE_ID:-}" ]; then
    echo "session-sync: indexed locally — the peer will pull on next connect. (Set PEER_DEVICE_ID to wait.)"
    return 0
  fi
  online=$(st_get "/rest/system/connections" 2>/dev/null | jq -r --arg d "$PEER_DEVICE_ID" '.connections[$d].connected // false')
  if [ "$online" != "true" ]; then
    echo "session-sync: peer offline — changes will push automatically when it reconnects."
    return 0
  fi
  _start=$(date +%s)
  for id in "$@"; do
    printf 'session-sync: pushing "%s" to peer ' "$id"
    while :; do
      comp=$(st_get "/rest/db/completion?folder=$id&device=$PEER_DEVICE_ID" | jq -r '.completion // 100')
      pct=$(printf '%.0f' "$comp")
      [ "$pct" -ge 100 ] && { echo "OK"; break; }
      _now=$(date +%s)
      [ $(( _now - _start )) -ge "$SYNC_WAIT_TIMEOUT" ] && { echo "(timeout — will finish in the background)"; break; }
      printf '.'; sleep 2
    done
  done
}
