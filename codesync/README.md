# codesync — hand off a Claude Code session between machines

Work with Claude Code on the **desktop**, close it, resume the *same session* (conversation +
code, including uncommitted edits) on the **laptop**, and have changes flow back — full local
Claude instance on each machine. Linux + macOS, even with different usernames.

**Read [`DESIGN.md`](./DESIGN.md) for the how/why.** This README is the setup + usage guide.

## How it works (one paragraph)

A Claude Code session is a JSONL file under `~/.claude/projects/<encoded-project-path>/`.
[Syncthing](https://syncthing.net) continuously mirrors two folders between your machines —
the project directory and that project's transcript folder — so either machine can
`claude --continue` the same session. Syncing is **opt-in**: it only happens when you run the
`/codesync:stop` skill, and only in a directory containing a `.codesync` marker.

The four skills ship as a small Claude Code **plugin** named `codesync` (`/codesync:enable`,
`/codesync:start`, `/codesync:stop`, `/codesync:disable`); the matching terminal commands (`codesync start`,
`codesync stop`, …) install to `~/.local/bin`.

## Prerequisites (both machines)

**`make setup` + `make install` handle all of this for you** (see [One-time setup](#one-time-setup)).
The details below are reference for doing it by hand.

| Tool | Linux | macOS |
|---|---|---|
| jq | `sudo apt install jq` | `brew install jq` |
| curl | preinstalled | preinstalled |

**Syncthing** — install it one of these ways (all work; the script needs no root):

```bash
bash codesync/install-syncthing.sh     # no-sudo: fetches the standalone binary to ~/.local/bin
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

Do these **on each machine**.

### 1. Put the project under your home
No sudo needed. The paths **may differ** between machines (different usernames/OSes are fine —
folders sync by Syncthing **Folder ID**, not path):
```bash
git clone <repo> ~/Development/<name>          # e.g. ~/Development/pluto
```
> Trade-off: with differing paths, the transcript's *internal* absolute paths reference the
> machine they were created on (Claude re-reads from the current dir, so continuing works). To
> avoid that entirely, use an identical username-neutral path like `/opt/dev/<name>` on both —
> costs a one-time `sudo mkdir /opt/dev && sudo chown $USER /opt/dev`. See DESIGN.md §6.

### 2. Install everything — via `make` (from the repo root)
```bash
make setup             # system packages: jq, curl, git
make install           # Syncthing (installs it if missing) + the `codesync` command → ~/.local/bin
make install-globally  # register the marketplace + install the `codesync` plugin (user scope)
# …or all three at once:  make all
```
`make install-globally` is what makes `/codesync:enable` · `/codesync:start` · `/codesync:stop` ·
`/codesync:disable` available in **every** project — it runs `claude plugin marketplace add <repo>`
+ `claude plugin install codesync@jrhyde-tools --scope user`. Run `/reload-plugins` (or restart
Claude) afterward. The pieces are also runnable directly: `bash codesync/install.sh` (command),
`bash codesync/install-syncthing.sh` (Syncthing).

### 3. Wire up the project — one command
From a Claude session in the project run the skill **`/codesync:enable`**, or run the script:
```bash
codesync enable ~/Development/<name> [peer-device-id]
```
It creates both Syncthing folders (`<name>-code`, `<name>-sessions`) with matching IDs, a
`.stignore`, `~/.config/codesync/config.sh`, and the `.codesync` marker — and prints
this machine's Device ID. If you pass the peer's Device ID it also shares the folders with it.

### 4. Pair the two machines (once)
In each Syncthing UI (<http://127.0.0.1:8384>): *Add Remote Device* with the other's Device ID,
then **accept the two shared folders**, pointing each at its local path. (Passing
`peer-device-id` in step 3 handles the share side; you still accept on the other machine.)

## Usage

```bash
cd ~/Development/<repo>    # codesync start/stop act on the repo you're IN
codesync start            # waits for sync, then resumes THIS repo's session
# ...work with Claude...
/codesync:stop            # before switching: writes HANDOFF.md, optional WIP commit, pushes the sync
# then exit Claude normally
```

- **Directory-aware:** `codesync start` and `/codesync:stop` resolve the project from your
  current directory (the nearest `.codesync` marker), so they work per-repo with no config
  switching. `codesync start <dir>` also works.
- Normal `claude` sessions anywhere else are unaffected — nothing syncs unless you're in a
  `.codesync` directory.
- `codesync start` passes extra args through to `claude` (default `--continue`; use
  `codesync start --resume` for the session picker).

## Multiple repos & 3+ machines

- **Many repos:** just `codesync enable ~/Development/<repo>` for each one. Every repo gets its
  own independent folder pair (`<repo>-code` / `<repo>-sessions`) and its own `.codesync` marker;
  they all sync at once. `codesync start`/`stop` pick the right one from your current directory.
- **3+ machines:** peers are a **list** (`PEER_DEVICE_IDS`). Pass every other machine's Device ID
  to `codesync enable` — e.g. on machine A: `codesync enable <repo> <B-id> <C-id>`, on B:
  `… <A-id> <C-id>`, etc. Peers are stored globally, so after the first `enable` you can add new
  repos with just `codesync enable <repo>` (no IDs) and they'll share with all known peers.
  `codesync stop` pushes to every peer that's currently online; the rest pull when they reconnect.
- **One machine per directory at a time** — codesync assumes sequential use; don't run the same
  project's session live on two machines simultaneously (Syncthing would create a conflict file).

## Rules & gotchas

- **Don't run the same session live on both machines at once** (append conflict on the JSONL).
  Close before switching.
- `codesync start` blocks until Syncthing reports **Up to Date**, so you never resume a half-synced
  transcript.
- Keep using **git** for real history — sync is for the seamless handoff, not versioning.

## Files

The `codesync` plugin lives in `codesync/` (plugin root); the repo root holds the marketplace
catalog that makes it installable:
```
<repo-root>/
├── .claude-plugin/
│   └── marketplace.json          local marketplace 'jrhyde-tools' → points at ./codesync
└── codesync/                     the 'codesync' plugin
    ├── .claude-plugin/
    │   └── plugin.json           plugin manifest (name: codesync, v1.0.0)
    ├── skills/                   plugin skills (folder name = /codesync:<name>)
    │   ├── enable/SKILL.md        → /codesync:enable
    │   ├── start/SKILL.md         → /codesync:start   (reminder to run `codesync start` in the terminal)
    │   ├── stop/SKILL.md          → /codesync:stop
    │   └── disable/SKILL.md       → /codesync:disable
    ├── DESIGN.md                 design rationale (read this)
    ├── README.md                 this guide
    ├── install.sh                installs the `codesync` command + the plugin (user scope)
    ├── install-syncthing.sh      no-sudo Syncthing installer + auto-start service (Linux/macOS)
    ├── config.example.sh         config template
    └── scripts/                  → installed to ~/.local/bin
        ├── codesync-lib.sh       shared library (Syncthing REST, sync logic, subcommands)
        └── codesync.sh    → codesync   (one command: start | stop | enable | disable | wait)
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `--continue` doesn't find the session on the other machine | Folder B not shared/accepted | Ensure the `<name>-sessions` folder is shared **and accepted** on both; the two machines' encoded folder names differ by design (they map by Folder **ID**, not name) |
| `codesync stop` says "sync not enabled" | No `.codesync` marker | `touch "$PROJECT_DIR/.codesync"` |
| "cannot find Syncthing config.xml" | Non-standard location | Set `SYNCTHING_API_KEY` in config.sh |
| Hangs on "waiting for folder" | Peer offline / not sharing that folder | Confirm both devices online and both folders shared + accepted |
| Conflict files (`*.sync-conflict-*`) | Edited/ran on both at once | Resolve, commit clean state to git |
