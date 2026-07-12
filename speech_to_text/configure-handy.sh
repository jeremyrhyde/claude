#!/usr/bin/env bash
# Apply the GNOME/Wayland fixes that make Handy dictate-and-type reliably.
# Idempotent; safe to re-run. Restarts Handy if it is currently running.
#
# Handy only writes its settings file after its FIRST launch, so run this once after you've
# started Handy at least once (and ideally downloaded a model).
#
# What it sets:
#   Handy settings (settings_store.json):
#     keyboard_implementation = handy_keys  (evdev global key capture; ctrl+space works w/o focus)
#     typing_tool             = ydotool     (wtype can't inject on GNOME's Mutter)
#     push_to_talk            = false       (toggle mode: tap on, tap off)
#     paste_method            = direct      (type text at the cursor)
#     clipboard_handling      = dont_modify (leave the user's clipboard alone)
#     overlay_position        = none        (harmless; overlay still spawns, focus fix below)
#     audio_feedback          = true        (marimba start/stop cue)
#     paste_delay_ms          = 150         (small settle delay)
#   GNOME (gsettings):
#     focus-new-windows = strict            (THE fix: Handy's overlay can't steal focus,
#                                            so typed text lands in your app, not the overlay)
set -euo pipefail

SETTINGS="$HOME/.local/share/com.pais.handy/settings_store.json"

# --- GNOME: stop new windows (Handy's recording overlay) from stealing focus ---
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.wm.preferences focus-new-windows 'strict'
  echo "  gnome focus-new-windows -> strict"
else
  echo "  (gsettings not found; skipping focus-new-windows — non-GNOME session?)"
fi

# --- Handy settings JSON ---
if [ ! -f "$SETTINGS" ]; then
  echo "Handy settings not found at: $SETTINGS"
  echo "Launch Handy once (env WEBKIT_DISABLE_DMABUF_RENDERER=1 HANDY_NO_GTK_LAYER_SHELL=1 handy),"
  echo "then re-run this script."
  exit 1
fi

WAS_RUNNING=no
if pgrep -x handy >/dev/null; then WAS_RUNNING=yes; echo "  stopping Handy"; pkill -x handy || true; sleep 2; fi

cp "$SETTINGS" "$SETTINGS.bak"
python3 - "$SETTINGS" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
s = d.setdefault("settings", {})
s["keyboard_implementation"] = "handy_keys"
s["typing_tool"]             = "ydotool"
s["push_to_talk"]            = False
s["paste_method"]            = "direct"
s["clipboard_handling"]      = "dont_modify"
s["overlay_position"]        = "none"
s["audio_feedback"]          = True
s["paste_delay_ms"]          = 150
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
for k in ("keyboard_implementation","typing_tool","push_to_talk","paste_method",
          "clipboard_handling","overlay_position","audio_feedback","paste_delay_ms"):
    print(f"  handy {k} -> {s[k]}")
PY

if [ "$WAS_RUNNING" = yes ]; then
  echo "  relaunching Handy"
  env WEBKIT_DISABLE_DMABUF_RENDERER=1 HANDY_NO_GTK_LAYER_SHELL=1 handy >/tmp/handy.log 2>&1 &
  sleep 3
  pgrep -x handy >/dev/null && echo "  Handy running" || echo "  WARN: Handy did not restart; launch it manually."
fi
echo "Done. Trigger dictation with Ctrl+Space (tap on, speak, tap off)."
