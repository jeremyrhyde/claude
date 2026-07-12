#!/bin/sh
# Push local changes (code + flushed transcript) to the peer. Gated on the project's
# .claude-sync marker, so it is a no-op in non-sync directories.
# Usage: sync-stop
set -eu
SS_LIB="${SESSION_SYNC_LIB:-$(dirname "$0")/session-sync-lib.sh}"
[ -f "$SS_LIB" ] || SS_LIB="$HOME/.local/bin/session-sync-lib.sh"
# shellcheck disable=SC1090
. "$SS_LIB"

[ -n "${PROJECT_DIR:-}" ] || die "PROJECT_DIR not set in config ($SESSION_SYNC_CONFIG)"

if [ ! -f "$PROJECT_DIR/.claude-sync" ]; then
  echo "session-sync: '$PROJECT_DIR' has no .claude-sync marker — sync not enabled, skipping."
  exit 0
fi

[ -n "${CODE_FOLDER_ID:-}" ] && [ -n "${SESSION_FOLDER_ID:-}" ] \
  || die "CODE_FOLDER_ID/SESSION_FOLDER_ID not set in config"

sync_push_folders "$CODE_FOLDER_ID" "$SESSION_FOLDER_ID"
echo "session-sync: sync-stop complete."
