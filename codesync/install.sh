#!/usr/bin/env bash
# Install the `codesync` command + the 'codesync' Claude Code plugin for the current user.
# Run this on BOTH machines. Idempotent. Does NOT touch Syncthing (see README for pairing).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SRC/.." && pwd)"
BIN="$HOME/.local/bin"
CFG="$HOME/.config/codesync"

mkdir -p "$BIN" "$CFG"

echo "==> Installing the 'codesync' command to $BIN"
install -m 0644 "$SRC/scripts/codesync-lib.sh" "$BIN/codesync-lib.sh"
install -m 0755 "$SRC/scripts/codesync.sh"     "$BIN/codesync"

echo "==> Config"
if [ -f "$CFG/config.sh" ]; then
  echo "    $CFG/config.sh already exists — left unchanged."
else
  echo "    No config yet — that's expected. Run 'codesync enable <project-dir>' (or /codesync:enable)"
  echo "    to generate $CFG/config.sh with this machine's real path + folder IDs."
fi

case ":$PATH:" in
  *":$BIN:"*) : ;;
  *) echo "NOTE: $BIN is not on your PATH — add it to your shell rc (e.g. export PATH=\"\$HOME/.local/bin:\$PATH\").";;
esac

for t in curl jq; do command -v "$t" >/dev/null 2>&1 || echo "NOTE: '$t' not found — install it (jq: apt install jq / brew install jq)."; done
command -v syncthing >/dev/null 2>&1 || echo "NOTE: Syncthing not found — run install-syncthing.sh (see README.md)."

cat <<'DONE'

==> Installed command: codesync (start | stop | enable | disable | wait)
    Next:
      1. Install the plugin globally:  make install-globally
         (or: claude plugin marketplace add <repo> && claude plugin install codesync@jrhyde-tools --scope user)
      2. Enable a project:  codesync enable <project-dir> [peer-device-id]
      3. Use:  codesync start  to begin a session, and  /codesync:stop  to hand off.
DONE
