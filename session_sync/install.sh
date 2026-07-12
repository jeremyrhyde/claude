#!/usr/bin/env bash
# Install the sync shell commands + the 'sync' Claude Code plugin for the current user.
# Run this on BOTH machines. Idempotent. Does NOT touch Syncthing (see README for pairing).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SRC/.." && pwd)"
BIN="$HOME/.local/bin"
CFG="$HOME/.config/session-sync"

mkdir -p "$BIN" "$CFG"

echo "==> Installing terminal commands to $BIN"
install -m 0644 "$SRC/scripts/session-sync-lib.sh" "$BIN/session-sync-lib.sh"
install -m 0755 "$SRC/scripts/sync-wait.sh"    "$BIN/sync-wait"     # helper
install -m 0755 "$SRC/scripts/sync-start.sh"   "$BIN/sync-start"    # begin a synced session
install -m 0755 "$SRC/scripts/sync-stop.sh"    "$BIN/sync-stop"     # push/hand off (also via /sync:stop)
install -m 0755 "$SRC/scripts/sync-enable.sh"  "$BIN/sync-enable"   # per-project setup (also via /sync:enable)
install -m 0755 "$SRC/scripts/sync-disable.sh" "$BIN/sync-disable"  # opt-out (also via /sync:disable)

echo "==> Installing the 'sync' plugin (skills: /sync:enable /sync:start /sync:stop /sync:disable)"
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add "$REPO_ROOT" 2>/dev/null || echo "    (marketplace already added)"
  if claude plugin install sync@jrhyde-tools --scope user 2>/dev/null; then
    echo "    installed 'sync' plugin (user scope — available in every project)"
  else
    echo "    NOTE: finish with:  claude plugin install sync@jrhyde-tools --scope user"
  fi
else
  echo "    'claude' CLI not on PATH yet — after it's available, run:"
  echo "      claude plugin marketplace add $REPO_ROOT"
  echo "      claude plugin install sync@jrhyde-tools --scope user"
fi

echo "==> Config"
if [ ! -f "$CFG/config.sh" ]; then
  install -m 0644 "$SRC/config.example.sh" "$CFG/config.sh"
  echo "    Wrote $CFG/config.sh — or just run /sync:enable (or sync-enable <dir>) to generate it."
else
  echo "    $CFG/config.sh already exists — left unchanged."
fi

case ":$PATH:" in
  *":$BIN:"*) : ;;
  *) echo "NOTE: $BIN is not on your PATH — add it to your shell rc (e.g. export PATH=\"\$HOME/.local/bin:\$PATH\").";;
esac

for t in curl jq; do command -v "$t" >/dev/null 2>&1 || echo "NOTE: '$t' not found — install it (jq: apt install jq / brew install jq)."; done
command -v syncthing >/dev/null 2>&1 || echo "NOTE: Syncthing not found — run install-syncthing.sh (see README.md)."

cat <<'DONE'

==> Installed commands: sync-start, sync-stop, sync-enable, sync-disable, sync-wait
    Installed plugin 'sync':  /sync:enable  /sync:start  /sync:stop  /sync:disable
    Next:
      1. Run /sync:enable (or: sync-enable <project-dir> [peer-device-id])
      2. Install + pair Syncthing; accept the two shared folders (README.md)
      3. Use:  sync-start  to begin a session, and  /sync:stop  to hand off.
DONE
