# session_sync — hand off a Claude Code session between machines

Work with Claude Code on the **desktop**, close it, resume the *same session* (conversation +
code, including uncommitted edits) on the **laptop**, and have changes flow back — full local
Claude instance on each machine. Linux + macOS, even with different usernames.

**Read [`DESIGN.md`](./DESIGN.md) for the how/why.** This README is the setup + usage guide.

## How it works (one paragraph)

A Claude Code session is a JSONL file under `~/.claude/projects/<encoded-project-path>/`.
[Syncthing](https://syncthing.net) continuously mirrors two folders between your machines —
the project directory and that project's transcript folder — so either machine can
`claude --continue` the same session. Syncing is **opt-in**: it only happens when you run the
`/handoff-close` skill, and only in a directory containing a `.claude-sync` marker.

## Prerequisites (both machines)

| Tool | Linux | macOS |
|---|---|---|
| jq | `sudo apt install jq` | `brew install jq` |
| curl | preinstalled | preinstalled |

**Syncthing** — install it one of these ways (all work; the script needs no root):

```bash
bash session_sync/install-syncthing.sh     # no-sudo: fetches the standalone binary to ~/.local/bin
#   or:  sudo apt install syncthing         # Linux (system package + optional systemd unit)
#   or:  brew install syncthing             # macOS
```

Then start it and (recommended) keep it running across reboots:

```bash
syncthing generate                          # first time: create config + keys
# start now:
syncthing serve --no-browser &              # UI at http://127.0.0.1:8384

# keep it running across reboots:
#   Linux (systemd user service):
systemctl --user enable --now syncthing.service   # if apt-installed; else use the unit in the tarball's etc/
#   macOS: `brew services start syncthing`, or the launchd plist from the release's etc/macos-launchd/
```

> Syncthing **v2** stores its config (and API key) at `~/.local/state/syncthing/config.xml`
> on Linux and `~/Library/Application Support/Syncthing/config.xml` on macOS — the scripts
> auto-detect both, so you normally don't set `SYNCTHING_API_KEY`.

## One-time setup

### 1. Same absolute project path on both machines
Use a username/OS-neutral path (see DESIGN.md §6):
```bash
sudo mkdir -p /opt/dev
sudo chown "$(id -un)":"$(id -gn)" /opt/dev
# put your project at /opt/dev/<name> on BOTH machines (encodes identically regardless of user/OS)
```

### 2. Install the commands + skill (run on both machines)
```bash
bash session_sync/install.sh
```
Installs `ccopen`, `cc-sync-wait`, `cc-sync-close` to `~/.local/bin`, the `/handoff-close`
skill to `~/.claude/skills`, and a config template to `~/.config/session-sync/config.sh`.

### 3. Set up Syncthing (both machines, once)
1. Start Syncthing (`syncthing` in a terminal, or enable the user service) and open its UI at
   <http://127.0.0.1:8384>.
2. **Pair the devices:** on each machine, *Add Remote Device* using the other's Device ID
   (Actions → Show ID).
3. **Add Folder A (code):** path = your project (`/opt/dev/<name>`), Folder ID = `claude-code`.
   Share it with the other device. Add a **`.stignore`** in the folder:
   ```
   node_modules
   target
   .venv
   dist
   build
   __pycache__
   .DS_Store
   *.log
   ```
4. **Add Folder B (sessions):** path = `~/.claude/projects/<encoded-path>/`
   (e.g. `-opt-dev-<name>`), Folder ID = `claude-sessions`. Share it with the other device.
   > The local path differs per machine (different `$HOME`); that's fine — Syncthing pairs by
   > Folder **ID**, and the encoded subfolder name matches because the project path matches.
5. (Optional) put each machine's Device ID into the *other* machine's
   `~/.config/session-sync/config.sh` as `PEER_DEVICE_ID` so `cc-sync-close` waits for the peer.

### 4. Configure + opt in
```bash
$EDITOR ~/.config/session-sync/config.sh      # set PROJECT_DIR + the two folder IDs
touch /opt/dev/<name>/.claude-sync            # opt this project into syncing
```

## Usage

```bash
ccopen            # sit down at either machine: waits for sync, then resumes the session
# ...work with Claude...
/handoff-close    # before switching: writes HANDOFF.md, optional WIP commit, pushes the sync
# then exit Claude normally
```

- Normal `claude` sessions anywhere else are unaffected — nothing syncs unless you run
  `/handoff-close` in a `.claude-sync` directory.
- `ccopen` passes extra args through to `claude` (default is `--continue`; use
  `ccopen --resume` for the session picker).

## Rules & gotchas

- **Don't run the same session live on both machines at once** (append conflict on the JSONL).
  Close before switching.
- `ccopen` blocks until Syncthing reports **Up to Date**, so you never resume a half-synced
  transcript.
- Keep using **git** for real history — sync is for the seamless handoff, not versioning.

## Files

```
session_sync/
├── DESIGN.md                     design rationale (read this)
├── README.md                     this guide
├── install.sh                    per-user installer for the session-sync tooling
├── install-syncthing.sh          no-sudo Syncthing binary installer (Linux/macOS)
├── config.example.sh             config template
├── scripts/
│   ├── session-sync-lib.sh       shared helpers (Syncthing REST, sync logic)
│   ├── sync-wait.sh    → cc-sync-wait
│   ├── sync-close.sh   → cc-sync-close
│   └── ccopen.sh       → ccopen
└── skills/handoff-close/SKILL.md → ~/.claude/skills/handoff-close/
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `--continue` doesn't find the session on the other machine | Project not at the identical absolute path | Ensure both use `/opt/dev/<name>` (§6); check the encoded folder names match |
| `cc-sync-close` says "sync not enabled" | No `.claude-sync` marker | `touch "$PROJECT_DIR/.claude-sync"` |
| "cannot find Syncthing config.xml" | Non-standard location | Set `SYNCTHING_API_KEY` in config.sh |
| Hangs on "waiting for folder" | Peer offline / not sharing that folder | Confirm both devices online and both folders shared + accepted |
| Conflict files (`*.sync-conflict-*`) | Edited/ran on both at once | Resolve, commit clean state to git |
