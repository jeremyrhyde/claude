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
`/sync:stop` skill, and only in a directory containing a `.claude-sync` marker.

The four skills ship as a small Claude Code **plugin** named `sync` (`/sync:enable`,
`/sync:start`, `/sync:stop`, `/sync:disable`); the matching terminal commands (`sync-start`,
`sync-stop`, …) install to `~/.local/bin`.

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

### 2. Install the tooling + Syncthing
```bash
bash session_sync/install.sh            # sync-* terminal commands + installs the 'sync' plugin (user scope)
bash session_sync/install-syncthing.sh  # Syncthing binary + auto-start service (or use apt/brew)
```
`install.sh` registers this repo as a local plugin marketplace and installs the `sync` plugin
(equivalent to `claude plugin marketplace add <repo> && claude plugin install sync@jrhyde-tools
--scope user`), so `/sync:enable` · `/sync:start` · `/sync:stop` · `/sync:disable` work in every
project.

### 3. Wire up the project — one command
From a Claude session in the project run the skill **`/sync:enable`**, or run the script:
```bash
sync-enable ~/Development/<name> [peer-device-id]
```
It creates both Syncthing folders (`<name>-code`, `<name>-sessions`) with matching IDs, a
`.stignore`, `~/.config/session-sync/config.sh`, and the `.claude-sync` marker — and prints
this machine's Device ID. If you pass the peer's Device ID it also shares the folders with it.

### 4. Pair the two machines (once)
In each Syncthing UI (<http://127.0.0.1:8384>): *Add Remote Device* with the other's Device ID,
then **accept the two shared folders**, pointing each at its local path. (Passing
`peer-device-id` in step 3 handles the share side; you still accept on the other machine.)

## Usage

```bash
sync-start            # sit down at either machine: waits for sync, then resumes the session
# ...work with Claude...
/sync:stop            # before switching: writes HANDOFF.md, optional WIP commit, pushes the sync
# then exit Claude normally
```

- Normal `claude` sessions anywhere else are unaffected — nothing syncs unless you run
  `/sync:stop` in a `.claude-sync` directory.
- `sync-start` passes extra args through to `claude` (default is `--continue`; use
  `sync-start --resume` for the session picker).

## Rules & gotchas

- **Don't run the same session live on both machines at once** (append conflict on the JSONL).
  Close before switching.
- `sync-start` blocks until Syncthing reports **Up to Date**, so you never resume a half-synced
  transcript.
- Keep using **git** for real history — sync is for the seamless handoff, not versioning.

## Files

The `sync` plugin lives in `session_sync/` (plugin root); the repo root holds the marketplace
catalog that makes it installable:
```
<repo-root>/
├── .claude-plugin/
│   └── marketplace.json          local marketplace 'jrhyde-tools' → points at ./session_sync
└── session_sync/                 the 'sync' plugin
    ├── .claude-plugin/
    │   └── plugin.json           plugin manifest (name: sync, v1.0.0)
    ├── skills/                   plugin skills (folder name = /sync:<name>)
    │   ├── enable/SKILL.md        → /sync:enable
    │   ├── start/SKILL.md         → /sync:start   (reminder to run `sync-start` in the terminal)
    │   ├── stop/SKILL.md          → /sync:stop
    │   └── disable/SKILL.md       → /sync:disable
    ├── DESIGN.md                 design rationale (read this)
    ├── README.md                 this guide
    ├── install.sh                installs terminal commands + the plugin (user scope)
    ├── install-syncthing.sh      no-sudo Syncthing installer + auto-start service (Linux/macOS)
    ├── config.example.sh         config template
    └── scripts/                  the terminal commands (→ ~/.local/bin)
        ├── session-sync-lib.sh   shared helpers (Syncthing REST, sync logic)
        ├── sync-wait.sh    → sync-wait     (helper: block until folders are synced)
        ├── sync-start.sh   → sync-start    (begin a synced session)
        ├── sync-stop.sh    → sync-stop     (push / hand off; also via /sync:stop)
        ├── sync-enable.sh  → sync-enable   (per-project setup; also via /sync:enable)
        └── sync-disable.sh → sync-disable  (opt-out; also via /sync:disable)
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `--continue` doesn't find the session on the other machine | Folder B not shared/accepted | Ensure the `<name>-sessions` folder is shared **and accepted** on both; the two machines' encoded folder names differ by design (they map by Folder **ID**, not name) |
| `sync-stop` says "sync not enabled" | No `.claude-sync` marker | `touch "$PROJECT_DIR/.claude-sync"` |
| "cannot find Syncthing config.xml" | Non-standard location | Set `SYNCTHING_API_KEY` in config.sh |
| Hangs on "waiting for folder" | Peer offline / not sharing that folder | Confirm both devices online and both folders shared + accepted |
| Conflict files (`*.sync-conflict-*`) | Edited/ran on both at once | Resolve, commit clean state to git |
