#!/bin/sh
# Open a synced Claude Code session: pull the latest from the peer (if this project is
# sync-enabled), cd into it, and resume. Open-only — installs no on-exit behavior, so quitting
# Claude never triggers a sync. Closing/pushing is done explicitly via the /handoff-close skill.
# Usage: ccopen [extra claude args...]   (default: --continue)
set -eu
SS_LIB="${SESSION_SYNC_LIB:-$(dirname "$0")/session-sync-lib.sh}"
[ -f "$SS_LIB" ] || SS_LIB="$HOME/.local/bin/session-sync-lib.sh"
# shellcheck disable=SC1090
. "$SS_LIB"

[ -n "${PROJECT_DIR:-}" ] || die "PROJECT_DIR not set in config ($SESSION_SYNC_CONFIG)"

if [ -f "$PROJECT_DIR/.claude-sync" ]; then
  [ -n "${CODE_FOLDER_ID:-}" ] && [ -n "${SESSION_FOLDER_ID:-}" ] \
    || die "CODE_FOLDER_ID/SESSION_FOLDER_ID not set in config"
  sync_wait_folders "$CODE_FOLDER_ID" "$SESSION_FOLDER_ID"
else
  echo "session-sync: no .claude-sync marker in '$PROJECT_DIR' — opening without a sync wait."
fi

cd "$PROJECT_DIR"
[ "$#" -gt 0 ] && exec claude "$@"
exec claude --continue
