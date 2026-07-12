# codesync configuration.
# Installed to ~/.config/codesync/config.sh by install.sh — edit it there (per machine).

# Absolute project path. MUST be identical on every machine (username/OS-neutral — see DESIGN.md §6).
PROJECT_DIR="/opt/dev/claude"

# Syncthing folder IDs you assign when pairing the two devices (shown in the Syncthing UI).
CODE_FOLDER_ID="claude-code"          # Folder A: the project directory ($PROJECT_DIR)
SESSION_FOLDER_ID="claude-sessions"   # Folder B: $HOME/.claude/projects/<encoded-path>/

# Optional: the OTHER machine's Syncthing device ID. If set, codesync stop will wait until the
# peer has actually received your changes (when it's online). Leave empty to just index & go.
PEER_DEVICE_ID=""

# Optional overrides (sensible defaults otherwise):
# SYNCTHING_URL="http://127.0.0.1:8384"
# SYNCTHING_API_KEY=""     # auto-detected from Syncthing's config.xml if empty
# SYNC_WAIT_TIMEOUT=120    # seconds to wait before giving up
