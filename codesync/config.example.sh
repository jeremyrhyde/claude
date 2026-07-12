# codesync GLOBAL config (per-machine) — REFERENCE ONLY.
# `codesync enable <dir> [peer-ids…]` writes and maintains ~/.config/codesync/config.sh for you.
# It holds only machine-wide settings; per-project folder IDs live in each repo's `.codesync`
# marker, so any number of repos are supported.

# Space-separated Syncthing Device IDs of the OTHER machines you sync with (2, 3, or more).
# `codesync stop` waits for each of these that's currently online to receive your changes.
PEER_DEVICE_IDS="I7FNI6T-7OS7SKC-… ANOTHER-MACHINE-ID-…"

# Subset of the above marked as Syncthing "introducers" (the always-on hub). Spokes point at the
# hub with `codesync enable <repo> --hub <hub-id>`; the hub auto-meshes them to each other.
HUB_DEVICE_IDS=""

# Optional overrides (sensible defaults otherwise):
# SYNCTHING_URL="http://127.0.0.1:8384"
# SYNCTHING_API_KEY=""     # auto-detected from Syncthing's config.xml if empty
# SYNC_WAIT_TIMEOUT=120    # seconds to wait before giving up
