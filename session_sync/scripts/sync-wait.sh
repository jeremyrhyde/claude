#!/bin/sh
# Wait until the given Syncthing folders are fully synced locally, then exit.
# Usage: sync-wait [folderID ...]   (defaults to CODE_FOLDER_ID + SESSION_FOLDER_ID)
set -eu
SS_LIB="${SESSION_SYNC_LIB:-$(dirname "$0")/session-sync-lib.sh}"
[ -f "$SS_LIB" ] || SS_LIB="$HOME/.local/bin/session-sync-lib.sh"
# shellcheck disable=SC1090
. "$SS_LIB"

if [ "$#" -eq 0 ]; then
  [ -n "${CODE_FOLDER_ID:-}" ] && [ -n "${SESSION_FOLDER_ID:-}" ] \
    || die "no folder IDs given and CODE_FOLDER_ID/SESSION_FOLDER_ID not set in config"
  set -- "$CODE_FOLDER_ID" "$SESSION_FOLDER_ID"
fi
sync_wait_folders "$@"
