# shellcheck shell=sh
# Shared library for the `codesync` command. Sourced by codesync (never executed directly).
# Provides: config loading, portable Syncthing API-key discovery, REST helpers, the
# scan/wait/push logic, and the enable/disable/start/stop/wait subcommand implementations.
# POSIX sh + jq (runs on Linux and macOS).
#
# Model (multi-repo + multi-peer):
#   - Global per-machine config (~/.config/codesync/config.sh) holds ONLY shared settings:
#       PEER_DEVICE_IDS="id1 id2 ..."   plus optional SYNCTHING_URL / SYNC_WAIT_TIMEOUT / SYNCTHING_API_KEY
#   - Each synced project is marked by a `.codesync` file at its root that records its
#       CODE_FOLDER_ID / SESSION_FOLDER_ID. start/stop resolve the project from the current
#       directory (walking up to the marker), so any number of repos work independently.

# --- config -----------------------------------------------------------------
: "${CODESYNC_CONFIG:=$HOME/.config/codesync/config.sh}"
# shellcheck disable=SC1090
[ -f "$CODESYNC_CONFIG" ] && . "$CODESYNC_CONFIG"
: "${PEER_DEVICE_IDS:=${PEER_DEVICE_ID:-}}"   # back-compat with the old single-peer var
: "${HUB_DEVICE_IDS:=}"                        # peers marked as Syncthing introducers (auto-mesh)
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

st_ready() {
  require_tools
  [ -n "${ST_KEY:-}" ] && return 0
  ST_KEY=$(syncthing_api_key) || die "could not obtain the Syncthing API key"
}
st_get()  { curl -fsS -H "X-API-Key: $ST_KEY" "$SYNCTHING_URL$1"; }
st_post() { curl -fsS -X POST -H "X-API-Key: $ST_KEY" "$SYNCTHING_URL$1"; }

# --- project resolution -----------------------------------------------------
# Walk up from a directory to find the nearest .codesync marker; prints the project root.
find_project_root() {
  d=$(cd "${1:-$PWD}" 2>/dev/null && pwd) || return 1
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -f "$d/.codesync" ] && { printf '%s' "$d"; return 0; }
    d=$(dirname "$d")
  done
  [ -f "/.codesync" ] && { printf '/'; return 0; }
  return 1
}

# Set CODE_ID / SESSION_ID for a project dir: from its .codesync marker if present, else derive.
load_project_ids() {
  _p="$1"; CODE_ID=""; SESSION_ID=""
  if [ -f "$_p/.codesync" ]; then
    CODE_ID=$(sed -n 's/^CODE_FOLDER_ID="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$_p/.codesync" | head -1)
    SESSION_ID=$(sed -n 's/^SESSION_FOLDER_ID="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$_p/.codesync" | head -1)
  fi
  [ -n "$CODE_ID" ]    || CODE_ID="$(basename "$_p")-code"
  [ -n "$SESSION_ID" ] || SESSION_ID="$(basename "$_p")-sessions"
}

# Combine + de-duplicate space-separated device-id lists (args), print one space-joined line.
merge_peers() { printf '%s\n' "$@" | tr ' ' '\n' | awk 'NF && !seen[$0]++' | tr '\n' ' ' | sed 's/ *$//'; }

# Rewrite the global config with new peer + hub lists, preserving any user overrides.
# $1 = peer ids, $2 = hub (introducer) ids
write_global_config() {
  cfgdir=$(dirname "$CODESYNC_CONFIG"); mkdir -p "$cfgdir"
  tmp="$CODESYNC_CONFIG.new"
  {
    echo "# codesync global config (per-machine) — managed by 'codesync enable'."
    echo "PEER_DEVICE_IDS=\"$1\""
    echo "HUB_DEVICE_IDS=\"$2\""
    [ -f "$CODESYNC_CONFIG" ] && grep -E '^(SYNCTHING_URL|SYNCTHING_API_KEY|SYNC_WAIT_TIMEOUT)=' "$CODESYNC_CONFIG" 2>/dev/null || true
  } > "$tmp"
  mv "$tmp" "$CODESYNC_CONFIG"
}

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

# Push the given folders to every configured peer that is currently online.
sync_push_folders() {
  st_ready
  for id in "$@"; do
    st_post "/rest/db/scan?folder=$id" >/dev/null || die "rescan failed for \"$id\" — is Syncthing running?"
    echo "codesync: rescanned \"$id\""
  done
  if [ -z "${PEER_DEVICE_IDS:-}" ]; then
    echo "codesync: indexed locally — peers will pull on next connect. (No PEER_DEVICE_IDS set.)"
    return 0
  fi
  conns=$(st_get "/rest/system/connections" 2>/dev/null || echo '{}')
  _start=$(date +%s)
  for peer in $PEER_DEVICE_IDS; do
    short=$(printf '%s' "$peer" | cut -c1-7)
    online=$(printf '%s' "$conns" | jq -r --arg d "$peer" '.connections[$d].connected // false')
    if [ "$online" != "true" ]; then
      echo "codesync: peer ${short}... offline — it'll pull when it reconnects."
      continue
    fi
    for id in "$@"; do
      printf 'codesync: pushing "%s" to %s... ' "$id" "$short"
      while :; do
        comp=$(st_get "/rest/db/completion?folder=$id&device=$peer" | jq -r '.completion // 100')
        pct=$(printf '%.0f' "$comp")
        [ "$pct" -ge 100 ] && { echo "OK"; break; }
        _now=$(date +%s)
        [ $(( _now - _start )) -ge "$SYNC_WAIT_TIMEOUT" ] && { echo "(timeout — finishing in background)"; break; }
        printf '.'; sleep 2
      done
    done
  done
}

# --- subcommands ------------------------------------------------------------
cmd_wait() {
  [ "$#" -ge 1 ] || die "usage: codesync wait <folder-id> [folder-id ...]"
  sync_wait_folders "$@"
}

cmd_start() {
  if [ "$#" -ge 1 ] && [ -d "$1" ]; then
    PROJECT_DIR=$(cd "$1" && pwd); shift
  else
    PROJECT_DIR=$(find_project_root "$PWD") \
      || die "not inside a codesync-enabled project — cd into one (or pass its path). Run 'codesync enable <dir>' first."
  fi
  [ -f "$PROJECT_DIR/.codesync" ] || die "'$PROJECT_DIR' is not codesync-enabled (no .codesync marker). Run: codesync enable '$PROJECT_DIR'"
  load_project_ids "$PROJECT_DIR"
  sync_wait_folders "$CODE_ID" "$SESSION_ID"
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
  PROJECT_DIR=$(find_project_root "$PWD") || {
    echo "codesync: not inside a codesync-enabled project — nothing to push."; return 0; }
  load_project_ids "$PROJECT_DIR"
  sync_push_folders "$CODE_ID" "$SESSION_ID"
  echo "codesync: stop complete for '$(basename "$PROJECT_DIR")'."
}

cmd_enable() {
  # Parse: <project-dir> [peer-id ...] [--hub <hub-id>]  (order-independent)
  DIR=""; NEW_PEERS=""; NEW_HUBS=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --hub)   shift; [ -n "${1:-}" ] || die "--hub requires a device id"; NEW_HUBS="$NEW_HUBS $1" ;;
      --hub=*) NEW_HUBS="$NEW_HUBS ${1#--hub=}" ;;
      -*)      die "unknown option '$1' (usage: codesync enable <project-dir> [peer-id ...] [--hub <hub-id>])" ;;
      *)       if [ -z "$DIR" ]; then DIR="$1"; else NEW_PEERS="$NEW_PEERS $1"; fi ;;
    esac
    shift
  done
  [ -n "$DIR" ] || die "usage: codesync enable <project-dir> [peer-device-id ...] [--hub <hub-id>]"
  have syncthing || die "syncthing not found — run install-syncthing.sh first"
  st_ready
  PROJECT_DIR=$(cd "$DIR" 2>/dev/null && pwd) || die "project dir '$DIR' not found"
  NEW_PEERS="$NEW_PEERS $NEW_HUBS"   # hubs are also peers (we share the folder with them)
  NAME=$(basename "$PROJECT_DIR")
  CODE_ID="${NAME}-code"; SESSION_ID="${NAME}-sessions"
  ENC=$(printf '%s' "$PROJECT_DIR" | sed 's:/:-:g')
  SESSION_DIR="$HOME/.claude/projects/$ENC"
  echo "codesync: project      $PROJECT_DIR"
  echo "codesync: code folder  id=$CODE_ID"
  echo "codesync: session dir  $SESSION_DIR (id=$SESSION_ID)"
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

  # per-project marker records the folder IDs (start/stop read this)
  printf 'CODE_FOLDER_ID="%s"\nSESSION_FOLDER_ID="%s"\n' "$CODE_ID" "$SESSION_ID" > "$PROJECT_DIR/.codesync"
  echo "codesync: marked $PROJECT_DIR/.codesync"

  # merge new peers/hubs into the global lists, then share this project's folders with all peers
  ALL_PEERS=$(merge_peers "$PEER_DEVICE_IDS" "$NEW_PEERS")
  ALL_HUBS=$(merge_peers "$HUB_DEVICE_IDS" "$NEW_HUBS")
  write_global_config "$ALL_PEERS" "$ALL_HUBS"
  echo "codesync: peers = ${ALL_PEERS:-<none>}"
  [ -n "$ALL_HUBS" ] && echo "codesync: hubs  = $ALL_HUBS (marked as introducers → auto-mesh)"
  for p in $ALL_PEERS; do
    short=$(printf '%s' "$p" | cut -c1-7)
    syncthing cli config devices add --device-id "$p" --name "peer-$short" 2>/dev/null \
      && echo "  added device $short..." || true
    case " $ALL_HUBS " in
      *" $p "*) syncthing cli config devices "$p" introducer set true 2>/dev/null \
                  && echo "  marked $short... as introducer (hub)" || true ;;
    esac
    for f in "$CODE_ID" "$SESSION_ID"; do
      syncthing cli config folders "$f" devices add --device-id "$p" 2>/dev/null \
        && echo "  shared '$f' with $short..." || true
    done
  done

  MYID=$(st_get /rest/system/status | jq -r .myID)
  cat <<EOF

codesync: enabled '$NAME'.
  This machine's Device ID: $MYID
  Hub-and-spoke (recommended for 3+): on the always-on HUB run
      codesync enable <dir> <spoke-id> [<spoke-id> ...]     # hub knows every spoke
  and on EACH other machine run
      codesync enable <dir> --hub $MYID                    # spoke points at the hub; auto-meshes
  Or full mesh: pass every other machine's id as plain peers.
  (peers + hub persist globally, so later 'codesync enable <repo>' reuses them.)
  Accept the shared folders on each side, then: 'codesync start' / '/codesync:stop'.
EOF
}

cmd_disable() {
  [ "$#" -ge 1 ] || die "usage: codesync disable <project-dir> [--remove-folders]"
  PROJECT_DIR=$(cd "$1" 2>/dev/null && pwd) || die "project dir '$1' not found"
  REMOVE="${2:-}"
  load_project_ids "$PROJECT_DIR"
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
    echo "codesync: folders removed. Your code and ~/.claude transcripts are untouched."
    echo "          (peers stay in the global config; other projects are unaffected.)"
  else
    echo "codesync: folders left registered. Re-enable with 'codesync enable', or fully tear"
    echo "          down with: codesync disable '$PROJECT_DIR' --remove-folders"
  fi
}
