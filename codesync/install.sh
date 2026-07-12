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

echo "==> Installing the 'codesync' plugin (/codesync:enable /codesync:start /codesync:stop /codesync:disable)"
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add "$REPO_ROOT" 2>/dev/null || echo "    (marketplace already added)"
  if claude plugin install codesync@jrhyde-tools --scope user 2>/dev/null; then
    echo "    installed 'codesync' plugin (user scope — available in every project)"
  else
    echo "    NOTE: finish with:  claude plugin install codesync@jrhyde-tools --scope user"
  fi
else
  echo "    'claude' CLI not on PATH yet — after it's available, run:"
  echo "      claude plugin marketplace add $REPO_ROOT"
  echo "      claude plugin install codesync@jrhyde-tools --scope user"
fi

echo "==> Config"
if [ ! -f "$CFG/config.sh" ]; then
  install -m 0644 "$SRC/config.example.sh" "$CFG/config.sh"
  echo "    Wrote $CFG/config.sh — or just run /codesync:enable (or: codesync enable <dir>) to generate it."
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

==> Installed command: codesync (start | stop | enable | disable | wait)
    Installed plugin 'codesync':  /codesync:enable  /codesync:start  /codesync:stop  /codesync:disable
    Next:
      1. Run /codesync:enable (or: codesync enable <project-dir> [peer-device-id])
      2. Install + pair Syncthing; accept the two shared folders (README.md)
      3. Use:  codesync start  to begin a session, and  /codesync:stop  to hand off.
DONE
