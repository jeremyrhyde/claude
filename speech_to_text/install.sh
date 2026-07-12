#!/usr/bin/env bash
# Reproducible installer for Handy (offline Whisper speech-to-text) on Ubuntu + GNOME/Wayland.
# Safe to re-run. After it finishes, do the one-time manual steps it prints (launch, model,
# then run configure-handy.sh). See README.md for the full story.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing runtime dependencies (apt)"
sudo apt-get update -qq
# ydotool = text injection via /dev/uinput (works on GNOME/Mutter where wtype cannot);
# wl-clipboard = clipboard; libgtk-layer-shell0 = Handy runtime dep.
sudo apt-get install -y ydotool wl-clipboard libgtk-layer-shell0 curl

echo "==> Ensuring evdev/uinput access (handy_keys reads /dev/input, ydotool writes /dev/uinput)"
# /dev/input/event* are group 'input' by default; /dev/uinput usually is not — add a udev rule.
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx input; then
  sudo usermod -aG input "$USER"
  echo "    Added $USER to the 'input' group (LOG OUT/IN or reboot for this to take effect)."
fi
if [ ! -e /etc/udev/rules.d/99-uinput-handy.rules ]; then
  echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' \
    | sudo tee /etc/udev/rules.d/99-uinput-handy.rules >/dev/null
  sudo modprobe uinput || true
  sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=uinput || true
  echo "    Installed udev rule granting the 'input' group access to /dev/uinput."
fi

echo "==> GNOME: focus-new-windows = strict (stops Handy's overlay from stealing focus)"
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.wm.preferences focus-new-windows 'strict'
fi

echo "==> Resolving latest Handy .deb (amd64) from GitHub releases"
API="https://api.github.com/repos/cjpais/Handy/releases/latest"
DEB_URL="$(curl -fsSL "$API" | grep -oE 'https://[^"]*_amd64\.deb' | head -n1)"
[ -n "${DEB_URL:-}" ] || { echo "ERROR: could not resolve .deb URL from $API" >&2; exit 1; }
echo "    $DEB_URL"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
curl -fSL "$DEB_URL" -o "$TMP/handy.deb"

echo "==> Installing Handy"
sudo apt-get install -y "$TMP/handy.deb"

echo "==> Desktop launcher override (NVIDIA/Wayland env fixes)"
APPDIR="$HOME/.local/share/applications"; mkdir -p "$APPDIR"
SRC_DESKTOP="$(ls /usr/share/applications/*[Hh]andy*.desktop 2>/dev/null | head -n1 || true)"
DEST_DESKTOP="$APPDIR/handy.desktop"
EXEC='Exec=env WEBKIT_DISABLE_DMABUF_RENDERER=1 HANDY_NO_GTK_LAYER_SHELL=1 handy'
if [ -n "$SRC_DESKTOP" ]; then
  sed -E "s|^Exec=.*|$EXEC|" "$SRC_DESKTOP" > "$DEST_DESKTOP"
else
  cat > "$DEST_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Handy
Comment=Offline speech-to-text (Whisper)
$EXEC
Terminal=false
Categories=Utility;AudioVideo;
EOF
fi
update-desktop-database "$APPDIR" 2>/dev/null || true

# Try to apply Handy's own settings now (only works if Handy has run before and created them).
echo "==> Applying Handy settings (if Handy has run before)"
bash "$SCRIPT_DIR/configure-handy.sh" || true

cat <<'DONE'

============================================================
 Handy installed. One-time manual steps:
   1. If you were just added to the 'input' group, LOG OUT/IN
      (or reboot) so ydotool + handy_keys get device access.
   2. Launch "Handy" from the app menu
      (or: env WEBKIT_DISABLE_DMABUF_RENDERER=1 HANDY_NO_GTK_LAYER_SHELL=1 handy)
   3. Grant microphone permission; finish onboarding.
   4. Settings -> Models: download & select "Whisper Large V3 Turbo".
   5. Run:  bash speech_to_text/configure-handy.sh
      (applies the keyboard/typing/focus fixes; needs the settings
       file that Handy creates on first launch)
   6. Dictate: focus any text field, tap Ctrl+Space, speak,
      tap Ctrl+Space again -> text types in at your cursor.
============================================================
DONE
