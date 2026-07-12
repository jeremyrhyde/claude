#!/usr/bin/env bash
# Install Syncthing for the current user (NO sudo) on Linux or macOS -> ~/.local/bin,
# generate its config, and set it up to auto-start on boot (systemd user unit / launchd).
# Pairing + folder setup is done afterwards in the Syncthing UI (see README).
# Flags: --no-service (install/generate only, skip auto-start setup).
set -euo pipefail

BIN="$HOME/.local/bin"; mkdir -p "$BIN"
WANT_SERVICE=1
[ "${1:-}" = "--no-service" ] && WANT_SERVICE=0

# --- 1. binary ---------------------------------------------------------------
ensure_binary() {
  if command -v syncthing >/dev/null 2>&1; then
    echo "==> syncthing present: $(command -v syncthing) ($(syncthing --version 2>/dev/null | awk '{print $2}'))"
    return 0
  fi
  case "$(uname -s)" in
    Linux)  os=linux ;;
    Darwin) os=macos ;;
    *) echo "Unsupported OS $(uname -s) — install manually (https://syncthing.net/downloads/)"; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported arch $(uname -m)"; exit 1 ;;
  esac
  # Linux assets are .tar.gz; macOS assets are .zip
  if [ "$os" = "macos" ]; then ext="zip"; else ext="tar.gz"; fi
  echo "==> Downloading latest Syncthing for ${os}-${arch} (.${ext})"
  URL="$(curl -fsSL https://api.github.com/repos/syncthing/syncthing/releases/latest \
    | grep -oE "https://[^\"]*syncthing-${os}-${arch}-[^\"]*\.${ext}" | grep -v '\.sig' | head -n1)"
  [ -n "$URL" ] || { echo "could not find a ${os}-${arch} .${ext} asset"; exit 1; }
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  ARC="$TMP/st.$ext"
  curl -fSL "$URL" -o "$ARC"
  if [ "$ext" = "zip" ]; then
    command -v unzip >/dev/null 2>&1 || { echo "unzip not found — install it or use: brew install syncthing"; exit 1; }
    unzip -q "$ARC" -d "$TMP"
  else
    tar -xzf "$ARC" -C "$TMP"
  fi
  SB="$(find "$TMP" -type f -name syncthing | head -n1)"
  [ -n "$SB" ] || { echo "syncthing binary not in archive"; exit 1; }
  install -m 0755 "$SB" "$BIN/syncthing"
  # macOS: strip the quarantine attribute if a downloader set it, so it can run
  [ "$os" = "macos" ] && xattr -d com.apple.quarantine "$BIN/syncthing" 2>/dev/null || true
  echo "    installed $("$BIN/syncthing" --version)"
}

st() { if command -v syncthing >/dev/null 2>&1; then syncthing "$@"; else "$BIN/syncthing" "$@"; fi; }

# --- 2. config ---------------------------------------------------------------
ensure_config() {
  if st cli show system >/dev/null 2>&1; then return 0; fi   # daemon already up = config exists
  for c in "$HOME/.local/state/syncthing/config.xml" "$HOME/.config/syncthing/config.xml" \
           "$HOME/Library/Application Support/Syncthing/config.xml"; do
    [ -f "$c" ] && return 0
  done
  echo "==> Generating Syncthing config"
  st generate >/dev/null 2>&1 || true
}

# --- 3. auto-start service ---------------------------------------------------
setup_service_linux() {
  if ! systemctl --user >/dev/null 2>&1; then
    echo "    systemd --user unavailable — start manually: syncthing serve --no-browser &"
    return 0
  fi
  unit="$HOME/.config/systemd/user/syncthing.service"; mkdir -p "$(dirname "$unit")"
  cat > "$unit" <<'EOF'
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization
Documentation=man:syncthing(1)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=%h/.local/bin/syncthing serve --no-browser --no-restart --logflags=0
Restart=on-failure
RestartSec=5
SuccessExitStatus=3 4
RestartForceExitStatus=3 4

[Install]
WantedBy=default.target
EOF
  # stop any ad-hoc (nohup) instance so the service can bind the ports
  pkill -x syncthing 2>/dev/null || true; sleep 1
  systemctl --user daemon-reload
  systemctl --user enable --now syncthing.service
  # survive logout / run headless (needs privilege; ignore if it prompts/fails)
  loginctl enable-linger "$(id -un)" 2>/dev/null \
    && echo "    lingering enabled (runs when logged out)" \
    || echo "    NOTE: for headless boot, run: sudo loginctl enable-linger $(id -un)"
  systemctl --user is-active syncthing.service >/dev/null 2>&1 \
    && echo "    syncthing.service is active" || echo "    WARN: service not active — check: systemctl --user status syncthing"
}

setup_service_macos() {
  plist="$HOME/Library/LaunchAgents/net.syncthing.syncthing.plist"; mkdir -p "$(dirname "$plist")"
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>net.syncthing.syncthing</string>
  <key>ProgramArguments</key>
  <array><string>$BIN/syncthing</string><string>serve</string><string>--no-browser</string></array>
  <key>KeepAlive</key><true/>
  <key>RunAtLoad</key><true/>
</dict></plist>
EOF
  pkill -x syncthing 2>/dev/null || true; sleep 1
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load -w "$plist" && echo "    launchd agent loaded" || echo "    WARN: launchctl load failed — load manually: launchctl load -w $plist"
}

ensure_binary
ensure_config
if [ "$WANT_SERVICE" = 1 ]; then
  echo "==> Setting up auto-start service"
  case "$(uname -s)" in
    Linux)  setup_service_linux ;;
    Darwin) setup_service_macos ;;
  esac
else
  echo "==> Skipping service setup (--no-service). Start with: syncthing serve --no-browser &"
fi

# wait for REST, then show the Device ID for pairing
for i in $(seq 1 15); do curl -fsS http://127.0.0.1:8384/rest/noauth/health >/dev/null 2>&1 && break; sleep 1; done
echo
echo "==> This machine's Device ID (use it to pair the other machine):"
st cli show system 2>/dev/null | (command -v jq >/dev/null && jq -r .myID || cat) || echo "    (open http://127.0.0.1:8384 -> Actions -> Show ID)"
cat <<'DONE'

Next: run  codesync enable <project-dir> [peer-id …] [--hub <hub-id>]  to set up a project
(it creates + shares the two Syncthing folders and writes ~/.config/codesync/config.sh).
DONE
