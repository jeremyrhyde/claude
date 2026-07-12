#!/bin/sh
# Opt a project OUT of syncing on THIS machine. Always removes the .claude-sync marker (so
# /sync-stop and sync-start no longer act on it). With --remove-folders it also unregisters the
# two Syncthing folders and clears config.sh. NEVER touches your code or transcripts.
# Usage: sync-disable <project-dir> [--remove-folders]
set -eu
SS_LIB="${SESSION_SYNC_LIB:-$(dirname "$0")/session-sync-lib.sh}"
[ -f "$SS_LIB" ] || SS_LIB="$HOME/.local/bin/session-sync-lib.sh"
# shellcheck disable=SC1090
. "$SS_LIB"

[ "$#" -ge 1 ] || die "usage: sync-disable <project-dir> [--remove-folders]"
PROJECT_DIR=$(cd "$1" 2>/dev/null && pwd) || die "project dir '$1' not found"
REMOVE="${2:-}"
NAME=$(basename "$PROJECT_DIR")
CODE_ID="${NAME}-code"
SESSION_ID="${NAME}-sessions"

# always: drop the marker
if [ -f "$PROJECT_DIR/.claude-sync" ]; then
  rm -f "$PROJECT_DIR/.claude-sync"
  echo "session-sync: removed marker $PROJECT_DIR/.claude-sync (syncing paused for this project)"
else
  echo "session-sync: no .claude-sync marker at '$PROJECT_DIR' (already disabled)"
fi

if [ "$REMOVE" = "--remove-folders" ]; then
  command -v syncthing >/dev/null 2>&1 || die "syncthing not found — cannot remove folders"
  st_ready
  for f in "$CODE_ID" "$SESSION_ID"; do
    syncthing cli config folders "$f" delete 2>/dev/null \
      && echo "session-sync: unregistered Syncthing folder '$f'" \
      || echo "session-sync: folder '$f' not present"
  done
  CFG="$HOME/.config/session-sync/config.sh"
  if [ -f "$CFG" ] && grep -q "PROJECT_DIR=\"$PROJECT_DIR\"" "$CFG" 2>/dev/null; then
    rm -f "$CFG"; echo "session-sync: removed $CFG"
  fi
  echo "session-sync: folders/config removed. Your code and ~/.claude transcripts are untouched."
else
  echo "session-sync: folders left registered. Re-enable anytime with sync-enable, or fully"
  echo "              tear down with: sync-disable '$PROJECT_DIR' --remove-folders"
fi
