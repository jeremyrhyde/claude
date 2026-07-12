# shellcheck shell=sh
# Shared library for the `codesync` command. Sourced by codesync (never executed directly).
# Provides: config loading, portable Syncthing API-key discovery, REST helpers, the
# scan/wait/push logic, and the enable/disable/start/stop/wait subcommand implementations.
# POSIX sh + jq (runs on Linux and macOS).

# --- config -----------------------------------------------------------------
: "${CODESYNC_CONFIG:=$HOME/.config/codesync/config.sh}"
# shellcheck disable=SC1090
[ -f "$CODESYNC_CONFIG" ] && . "$CODESYNC_CONFIG"
: "${SYNCTHING_URL:=http://127.0.0.1:8384}"
: "${SYNC_WAIT_TIMEOUT:=120}"

die()  { printf 'codesync: %s\n' "$*" >&2; exit 1; }
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
  if have syncthing; then
    p=$(syncthing --paths 2>/dev/null | awk -F': *' 'tolower($1) ~ /config/ {print $2; exit}')
    [ -n "$p" ] && [ -f "$p/config.xml" ] && { printf '%s' "$p/config.xml"; return 0; }
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

sync_wait_folders() {
  st_ready
  sync_scan "$@"
  _start=$(date +%s)
  for id in "$@"; do
    printf 'codesync: waiting for folder "%s" ' "$id"
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
  echo "codesync: up to date."
}

sync_push_folders() {
  st_ready
  for id in "$@"; do
    st_post "/rest/db/scan?folder=$id" >/dev/null || die "rescan failed for \"$id\" — is Syncthing running?"
    echo "codesync: rescanned \"$id\""
  done
  if [ -z "${PEER_DEVICE_ID:-}" ]; then
    echo "codesync: indexed locally — the peer will pull on next connect. (Set PEER_DEVICE_ID to wait.)"
    return 0
  fi
  online=$(st_get "/rest/system/connections" 2>/dev/null | jq -r --arg d "$PEER_DEVICE_ID" '.connections[$d].connected // false')
  if [ "$online" != "true" ]; then
    echo "codesync: peer offline — changes will push automatically when it reconnects."
    return 0
  fi
  _start=$(date +%s)
  for id in "$@"; do
    printf 'codesync: pushing "%s" to peer ' "$id"
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

# --- subcommands ------------------------------------------------------------
cmd_wait() {
  if [ "$#" -eq 0 ]; then
    [ -n "${CODE_FOLDER_ID:-}" ] && [ -n "${SESSION_FOLDER_ID:-}" ] \
      || die "no folder IDs given and CODE_FOLDER_ID/SESSION_FOLDER_ID not set in config"
    set -- "$CODE_FOLDER_ID" "$SESSION_FOLDER_ID"
  fi
  sync_wait_folders "$@"
}

cmd_start() {
  [ -n "${PROJECT_DIR:-}" ] || die "PROJECT_DIR not set in config ($CODESYNC_CONFIG)"
  if [ -f "$PROJECT_DIR/.codesync" ]; then
    [ -n "${CODE_FOLDER_ID:-}" ] && [ -n "${SESSION_FOLDER_ID:-}" ] || die "CODE_FOLDER_ID/SESSION_FOLDER_ID not set in config"
    sync_wait_folders "$CODE_FOLDER_ID" "$SESSION_FOLDER_ID"
  else
    echo "codesync: no .codesync marker in '$PROJECT_DIR' — opening without a sync wait."
  fi
  cd "$PROJECT_DIR"
  [ "$#" -gt 0 ] && exec claude "$@"
  ENC=$(printf '%s' "$PROJECT_DIR" | sed 's:/:-:g')
  if ls "$HOME/.claude/projects/$ENC"/*.jsonl >/dev/null 2>&1; then
    exec claude --continue
  else
    echo "codesync: no existing session for this project yet — starting a fresh one."
    exec claude
  fi
}

cmd_stop() {
  [ -n "${PROJECT_DIR:-}" ] || die "PROJECT_DIR not set in config ($CODESYNC_CONFIG)"
  if [ ! -f "$PROJECT_DIR/.codesync" ]; then
    echo "codesync: '$PROJECT_DIR' has no .codesync marker — sync not enabled, skipping."
    return 0
  fi
  [ -n "${CODE_FOLDER_ID:-}" ] && [ -n "${SESSION_FOLDER_ID:-}" ] || die "CODE_FOLDER_ID/SESSION_FOLDER_ID not set in config"
  sync_push_folders "$CODE_FOLDER_ID" "$SESSION_FOLDER_ID"
  echo "codesync: stop complete."
}

cmd_enable() {
  [ "$#" -ge 1 ] || die "usage: codesync enable <project-dir> [peer-device-id]"
  have syncthing || die "syncthing not found — run install-syncthing.sh first"
  st_ready
  PROJECT_DIR=$(cd "$1" 2>/dev/null && pwd) || die "project dir '$1' not found"
  PEER="${2:-}"
  NAME=$(basename "$PROJECT_DIR")
  CODE_ID="${NAME}-code"; SESSION_ID="${NAME}-sessions"
  ENC=$(printf '%s' "$PROJECT_DIR" | sed 's:/:-:g')
  SESSION_DIR="$HOME/.claude/projects/$ENC"
  echo "codesync: project      $PROJECT_DIR"
  echo "codesync: code folder  id=$CODE_ID"
  echo "codesync: session dir  $SESSION_DIR"
  echo "codesync: session id   $SESSION_ID"
  mkdir -p "$SESSION_DIR"

  if [ ! -f "$PROJECT_DIR/.stignore" ]; then
    cat > "$PROJECT_DIR/.stignore" <<'EOF'
.venv
node_modules
target
__pycache__
*.pyc
dist
build
.DS_Store
*.log
.env
EOF
    echo "codesync: wrote $PROJECT_DIR/.stignore"
  fi

  _folder_exists() { syncthing cli config folders list 2>/dev/null | grep -qx "$1"; }
  _add_folder() {
    if _folder_exists "$1"; then echo "codesync: folder '$1' already registered"; return 0; fi
    syncthing cli config folders add --id "$1" --label "$1" --path "$2" \
      && echo "codesync: added folder '$1'" || die "failed to add folder '$1'"
  }
  _add_folder "$CODE_ID" "$PROJECT_DIR"
  _add_folder "$SESSION_ID" "$SESSION_DIR"

  CFG_DIR="$HOME/.config/codesync"; mkdir -p "$CFG_DIR"
  cat > "$CFG_DIR/config.sh" <<EOF
# codesync config (generated on $(uname -sn))
PROJECT_DIR="$PROJECT_DIR"
CODE_FOLDER_ID="$CODE_ID"
SESSION_FOLDER_ID="$SESSION_ID"
PEER_DEVICE_ID="$PEER"
EOF
  echo "codesync: wrote $CFG_DIR/config.sh"
  touch "$PROJECT_DIR/.codesync"
  echo "codesync: marked $PROJECT_DIR/.codesync"

  if [ -n "$PEER" ]; then
    echo "codesync: sharing with peer $PEER"
    syncthing cli config devices add --device-id "$PEER" --name peer 2>/dev/null \
      && echo "  added peer device" || echo "  peer device already present (or add skipped)"
    for f in "$CODE_ID" "$SESSION_ID"; do
      syncthing cli config folders "$f" devices add --device-id "$PEER" 2>/dev/null \
        && echo "  shared '$f' with peer" || echo "  '$f' already shared (or share skipped)"
    done
  fi

  MYID=$(st_get /rest/system/status | jq -r .myID)
  cat <<EOF

codesync: enabled for '$NAME'.
  This machine's Device ID: $MYID
  On the OTHER machine, clone the project under ~/… (path may differ), then run:
      codesync enable <that-project-dir> $MYID
  Finally, accept the shared folders on each side (Syncthing UI or 'syncthing cli').
  Then use:  codesync start  to begin, and  /codesync:stop  to hand off.
EOF
}

cmd_disable() {
  [ "$#" -ge 1 ] || die "usage: codesync disable <project-dir> [--remove-folders]"
  PROJECT_DIR=$(cd "$1" 2>/dev/null && pwd) || die "project dir '$1' not found"
  REMOVE="${2:-}"
  NAME=$(basename "$PROJECT_DIR"); CODE_ID="${NAME}-code"; SESSION_ID="${NAME}-sessions"
  if [ -f "$PROJECT_DIR/.codesync" ]; then
    rm -f "$PROJECT_DIR/.codesync"
    echo "codesync: removed marker $PROJECT_DIR/.codesync (syncing paused for this project)"
  else
    echo "codesync: no .codesync marker at '$PROJECT_DIR' (already disabled)"
  fi
  if [ "$REMOVE" = "--remove-folders" ]; then
    have syncthing || die "syncthing not found — cannot remove folders"
    st_ready
    for f in "$CODE_ID" "$SESSION_ID"; do
      syncthing cli config folders "$f" delete 2>/dev/null \
        && echo "codesync: unregistered Syncthing folder '$f'" \
        || echo "codesync: folder '$f' not present"
    done
    CFG="$HOME/.config/codesync/config.sh"
    if [ -f "$CFG" ] && grep -q "PROJECT_DIR=\"$PROJECT_DIR\"" "$CFG" 2>/dev/null; then
      rm -f "$CFG"; echo "codesync: removed $CFG"
    fi
    echo "codesync: folders/config removed. Your code and ~/.claude transcripts are untouched."
  else
    echo "codesync: folders left registered. Re-enable with 'codesync enable', or fully tear"
    echo "          down with: codesync disable '$PROJECT_DIR' --remove-folders"
  fi
}
