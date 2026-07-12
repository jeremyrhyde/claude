#!/bin/sh
# codesync — cross-machine Claude Code session sync via Syncthing.
#   codesync start [claude args…]                begin/resume a synced session
#   codesync stop                                push / hand off (usually via /codesync:stop)
#   codesync enable  <project-dir> [peer-id]     set up a project for syncing
#   codesync disable <project-dir> [--remove-folders]   opt a project out
#   codesync wait    [folder-id …]               block until folders are synced (helper)
set -eu
SS_LIB="${CODESYNC_LIB:-$(dirname "$0")/codesync-lib.sh}"
[ -f "$SS_LIB" ] || SS_LIB="$HOME/.local/bin/codesync-lib.sh"
# shellcheck disable=SC1090
. "$SS_LIB"

usage() {
  cat <<'EOF'
codesync — cross-machine Claude Code session sync (Syncthing)

  codesync start [claude args…]              begin/resume a synced session
  codesync stop                              push / hand off (usually via /codesync:stop)
  codesync enable  <project-dir> [peer-id]   set up a project for syncing
  codesync disable <project-dir> [--remove-folders]
  codesync wait    [folder-id …]             block until folders are synced (helper)
EOF
}

cmd="${1:-}"
[ "$#" -gt 0 ] && shift || true
case "$cmd" in
  start)   cmd_start "$@" ;;
  stop)    cmd_stop "$@" ;;
  enable)  cmd_enable "$@" ;;
  disable) cmd_disable "$@" ;;
  wait)    cmd_wait "$@" ;;
  ""|-h|--help|help) usage ;;
  *) die "unknown subcommand '$cmd' (try: codesync --help)" ;;
esac
