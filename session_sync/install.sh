#!/usr/bin/env bash
# Install the session-sync commands + the handoff-close skill for the current user.
# Run this on BOTH machines. Idempotent. Does NOT touch Syncthing (see README for pairing).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
SKILLS="$HOME/.claude/skills"
CFG="$HOME/.config/session-sync"

mkdir -p "$BIN" "$SKILLS/handoff-close" "$CFG"

echo "==> Installing scripts to $BIN"
install -m 0644 "$SRC/scripts/session-sync-lib.sh" "$BIN/session-sync-lib.sh"
install -m 0755 "$SRC/scripts/sync-wait.sh"  "$BIN/cc-sync-wait"
install -m 0755 "$SRC/scripts/sync-close.sh" "$BIN/cc-sync-close"
install -m 0755 "$SRC/scripts/ccopen.sh"     "$BIN/ccopen"

echo "==> Installing handoff-close skill to $SKILLS/handoff-close"
install -m 0644 "$SRC/skills/handoff-close/SKILL.md" "$SKILLS/handoff-close/SKILL.md"

echo "==> Config"
if [ ! -f "$CFG/config.sh" ]; then
  install -m 0644 "$SRC/config.example.sh" "$CFG/config.sh"
  echo "    Wrote $CFG/config.sh — EDIT IT (PROJECT_DIR, folder IDs, optional PEER_DEVICE_ID)."
else
  echo "    $CFG/config.sh already exists — left unchanged (compare with config.example.sh for new keys)."
fi

case ":$PATH:" in
  *":$BIN:"*) : ;;
  *) echo "NOTE: $BIN is not on your PATH — add it to your shell rc (e.g. export PATH=\"\$HOME/.local/bin:\$PATH\").";;
esac

# Sanity: do the tools exist?
for t in curl jq; do command -v "$t" >/dev/null 2>&1 || echo "NOTE: '$t' not found — install it (jq: apt install jq / brew install jq)."; done
command -v syncthing >/dev/null 2>&1 || echo "NOTE: Syncthing not found — install & pair it (see README.md)."

cat <<'DONE'

==> Installed: ccopen, cc-sync-wait, cc-sync-close, and the /handoff-close skill.
    Next:
      1. Edit ~/.config/session-sync/config.sh
      2. Install + pair Syncthing; create the two shared folders (README.md)
      3. touch "$PROJECT_DIR/.claude-sync"   # opt this project into syncing
      4. Use: `ccopen` to start, `/handoff-close` to hand off.
DONE
