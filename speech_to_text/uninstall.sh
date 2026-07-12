#!/usr/bin/env bash
# Remove Handy and revert the changes this setup made.
# Downloaded Whisper models (under ~/.local/share) are left in place; delete manually if wanted.
set -euo pipefail

echo "==> Reverting GNOME focus-new-windows to default"
command -v gsettings >/dev/null 2>&1 && \
  gsettings reset org.gnome.desktop.wm.preferences focus-new-windows || true

echo "==> Removing desktop override"
rm -f "$HOME/.local/share/applications/handy.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "==> Removing udev rule for /dev/uinput"
sudo rm -f /etc/udev/rules.d/99-uinput-handy.rules
sudo udevadm control --reload-rules 2>/dev/null || true

echo "==> Removing Handy package"
PKG="$(dpkg -l 2>/dev/null | awk 'tolower($2) ~ /^handy$/ {print $2; exit}')"
if [ -n "${PKG:-}" ]; then sudo apt-get remove -y "$PKG"; else echo "  no Handy package found"; fi

echo "Done. (The 'input' group membership was left as-is; remove with: sudo gpasswd -d \$USER input)"
