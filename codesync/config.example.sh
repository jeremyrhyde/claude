# codesync configuration — REFERENCE ONLY.
# You normally never write this by hand: `codesync enable <project-dir>` (or /codesync:enable)
# generates ~/.config/codesync/config.sh for you, with the real paths + folder IDs.
#
# Paths MAY differ per machine (home-based is fine — folders sync by Syncthing Folder ID, not
# path). See DESIGN.md §6.

PROJECT_DIR="$HOME/Development/pluto"    # this machine's absolute project path (e.g. /Users/you/Development/pluto)

# Syncthing folder IDs (codesync enable derives these from the project name: <name>-code / <name>-sessions).
CODE_FOLDER_ID="pluto-code"             # Folder A: the project directory ($PROJECT_DIR)
SESSION_FOLDER_ID="pluto-sessions"      # Folder B: $HOME/.claude/projects/<encoded-path>/

# Optional: the OTHER machine's Syncthing device ID. If set, `codesync stop` waits until the
# peer has actually received your changes (when it's online). Leave empty to just index & go.
PEER_DEVICE_ID=""

# Optional overrides (sensible defaults otherwise):
# SYNCTHING_URL="http://127.0.0.1:8384"
# SYNCTHING_API_KEY=""     # auto-detected from Syncthing's config.xml if empty
# SYNC_WAIT_TIMEOUT=120    # seconds to wait before giving up
