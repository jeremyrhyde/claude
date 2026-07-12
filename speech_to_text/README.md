# Handy speech-to-text setup (Ubuntu 24.04 · GNOME · Wayland · NVIDIA)

Local, offline dictation that types transcribed text wherever your cursor is — terminals,
browsers, docs. Powered by [Handy](https://github.com/cjpais/Handy), which bundles
`whisper.cpp` + downloadable Whisper models (no separate Whisper install needed).

## Quick start

```bash
bash speech_to_text/install.sh           # deps, uinput access, GNOME focus fix, .deb, launcher
# then, one time in the GUI: launch Handy, grant mic, download & select "Whisper Large V3 Turbo"
bash speech_to_text/configure-handy.sh   # applies the settings that make it work
```

Then focus any text field, tap **Ctrl+Space**, speak, tap **Ctrl+Space** again → text types in.
A marimba sound marks start/stop.

> If `install.sh` just added you to the `input` group, **log out/in (or reboot) once** so
> `ydotool` and `handy_keys` get device access.

## What the scripts do

- **`install.sh`** — installs `ydotool` + `wl-clipboard` + `libgtk-layer-shell0`; grants your
  user access to `/dev/uinput` and `/dev/input` (udev rule + `input` group); sets GNOME
  `focus-new-windows=strict`; installs the latest Handy `.deb`; writes a launcher with the
  required env vars.
- **`configure-handy.sh`** — applies Handy's `settings_store.json` values (below). Idempotent;
  restarts Handy. Run it **after** Handy's first launch (Handy creates the file on first run).
- **`uninstall.sh`** — removes the package + launcher + udev rule and reverts the GNOME setting.

## Working configuration

| Layer | Setting | Purpose |
|---|---|---|
| GNOME | `focus-new-windows = strict` | Stops Handy's recording overlay from stealing focus |
| Handy | `keyboard_implementation = handy_keys` | Global Ctrl+Space capture via evdev |
| Handy | `typing_tool = ydotool` | Text injection via `/dev/uinput` |
| Handy | `push_to_talk = false` | Toggle: tap on, tap off |
| Handy | `paste_method = direct` | Types at the cursor (works in terminals) |
| Launcher | `WEBKIT_DISABLE_DMABUF_RENDERER=1`, `HANDY_NO_GTK_LAYER_SHELL=1` | Fixes blank window / overlay on NVIDIA-Wayland |
| System | user in `input` group | `handy_keys` reads `/dev/input`, `ydotool` writes `/dev/uinput` |

Trigger is Handy's built-in **Ctrl+Space** (Settings → Bindings to change it).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| **Typed text lands in the wrong window** / only shows after you click away | The recording overlay steals focus | `gsettings set org.gnome.desktop.wm.preferences focus-new-windows 'strict'` |
| **Blank / white Handy window** | WebKit DMABUF on NVIDIA | Launch with `WEBKIT_DISABLE_DMABUF_RENDERER=1` (already in the desktop launcher) |
| **"Failed to Paste Text"** | `wtype` can't inject on GNOME/Mutter | Set `typing_tool = ydotool`; ensure `/dev/uinput` is writable (`ls -l /dev/uinput` → group `input`, and you're in it) |
| **Ctrl+Space only works when a Handy window is focused** | Using the `tauri` shortcut backend | Set `keyboard_implementation = handy_keys`; you must be in the `input` group (`/dev/input` read access) |
| **Nothing happens / no device access after install** | `input` group not active yet | Log out/in or reboot once |
| **Transcript appears in Handy history but never types out** | Focus or injection issue (above two rows) | Apply the focus fix + `handy_keys` + `ydotool`, then restart Handy |
| **Have to hold the key** | Push-to-talk mode | Set `push_to_talk = false` |

### Verify a healthy state
```bash
pgrep -x handy                                              # exactly one instance
grep 'handy-keys shortcuts initialized' /tmp/handy.log      # global key capture active
gsettings get org.gnome.desktop.wm.preferences focus-new-windows   # -> 'strict'
ydotool type '' && echo uinput-ok                           # /dev/uinput writable
id -nG | grep -q input && echo in-input-group               # device access
```
Handy's log is at `/tmp/handy.log` (this setup redirects output there).

## Tips

- **`focus-new-windows=strict` is global** — *any* new window opens without grabbing focus
  (click/alt-tab to it). Revert: `gsettings reset org.gnome.desktop.wm.preferences focus-new-windows`.
- **Model**: `Whisper Large V3 Turbo` runs on the GPU via Vulkan. For lighter CPU use, pick
  `Parakeet V3` or a smaller model in Settings → Models.
- **Turn off the marimba**: Settings → disable audio feedback.

## Portability

`install.sh` + `configure-handy.sh` reproduce this on any Ubuntu/GNOME/Wayland machine. On
other distros grab the AppImage/`.rpm` from the
[releases page](https://github.com/cjpais/Handy/releases) and keep the same settings +
`focus-new-windows=strict`. Per-machine manual steps: grant mic + download the model.
