# Design: Claude Code session handoff & sync (desktop ↔ laptop, Linux + macOS)

Status: **Implemented.** This is the original design rationale (tools, sync model,
cross-platform + different-username handling). Some details evolved during implementation —
the shipped naming/packaging is the **`sync` plugin** (`/sync:enable` · `/sync:start` ·
`/sync:stop` · `/sync:disable`) plus `sync-*` terminal commands, and the default project path
is home-based (`~/Development/<name>`, not `/opt/dev`). **See [README.md](./README.md) for the
current, authoritative setup + usage.**

## 1. Goal & non-goals

**Goal.** Work with Claude Code on a project on the **desktop**; close it; reopen the *same
session* (conversation + code, including uncommitted edits) on the **laptop** at a coffee
shop; work; close it; return home with the **desktop up to date**. Full local Claude Code
instance on each machine — not a remote/browser view. Must work across **Linux and macOS**
with **different usernames** per machine.

**Non-goals.** Real-time co-editing (never run the same session live on both at once); a git
replacement (git still owns real history); cloud session hosting (stays peer-to-peer/local).

## 2. Why this works: how Claude Code stores a session

A session is a plain **JSONL transcript file**. Sessions are grouped per project in a folder
named after the project's **absolute path**, `/`→`-` encoded:

```
$HOME/.claude/projects/<encoded-abs-project-path>/<session-uuid>.jsonl
   e.g.  /opt/dev/claude   ->   -opt-dev-claude
```

`claude --resume`/`--continue` in a project dir reads the transcripts whose encoded folder
matches the current working directory. So "reopen the same session elsewhere" = **make the
transcript present on the other machine at the matching encoded path, with the code at the
matching absolute path**, then `claude --resume`.

Two consequences drive the design:
1. Sync **two folders**: the project code, and that project's transcript folder.
2. The **absolute project path must be identical on both machines** — the crux of both the
   different-username and different-OS problem (§6).

## 3. Architecture overview

```
        Desktop (any user/OS)                          Laptop (any user/OS)
 ┌────────────────────────────────┐          ┌────────────────────────────────┐
 │ /opt/dev/claude                 │◄────────►│ /opt/dev/claude                 │  Folder A: CODE
 │ (code + uncommitted edits)      │ Syncthing│ (SAME absolute path — §6)       │
 ├────────────────────────────────┤   (P2P,  ├────────────────────────────────┤
 │ $HOME/.claude/projects/         │◄────────►│ $HOME/.claude/projects/         │  Folder B: SESSION
 │   -opt-dev-claude/  (JSONL)     │ TLS      │   -opt-dev-claude/  (same name)  │
 └────────────────────────────────┘          └────────────────────────────────┘
   full local `claude` instance                 full local `claude` instance
```

Syncthing continuously mirrors both folders. No manual commit/pull for the handoff; git is
used only for real milestones.

## 4. Required tools

| Tool | Role | Linux install | macOS install |
|---|---|---|---|
| **Syncthing** | Continuous P2P sync of the two folders | `apt install syncthing` | `brew install syncthing` |
| **jq** | Parse Syncthing REST JSON in scripts | `apt install jq` | `brew install jq` |
| **curl** | Talk to Syncthing's local REST API | preinstalled | preinstalled |
| **git**, **Claude Code** | Version history; the sessions | already present | already present |

Syncthing's local REST API is `http://127.0.0.1:8384`, guarded by an API key. See §7.6 for
locating the key portably (it differs by OS).

## 5. What gets synced (and what must not)

**Folder A — project code:** `/opt/dev/claude` (see §6). `.stignore` skips regenerable/heavy
dirs:
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
`.git` is synced (keeps branch/commit state aligned) — safe under the sequential model.

**Folder B — session transcripts:** only this project's encoded subfolder,
`$HOME/.claude/projects/-opt-dev-claude/`. Scoping to the subfolder keeps unrelated,
home-path-specific sessions out.

**Never sync:** `~/.claude/.credentials.json`, `~/.claude.json`, or the rest of `~/.claude` —
each machine authenticates independently.

## 6. Same absolute path across different usernames **and** OSes

**The problem.** The session folder name embeds the absolute project path, which by default
includes the username (`/home/mistymts/…`, `/Users/jeremy/…`). Different user or OS →
different encoded folder → `--resume` can't find the session. The JSONL also records the
absolute `cwd`, so a path mismatch is doubly bad.

**The fix — a username- and OS-neutral root at the same absolute path on both machines.** Use
a path that has nothing to do with `$HOME`:

```bash
# On BOTH machines (Linux and macOS both allow this):
sudo mkdir -p /opt/dev
sudo chown "$(id -un)":"$(id -gn)" /opt/dev     # each machine's own user owns it
# The project lives at /opt/dev/claude on both -> encodes to -opt-dev-claude on both.
```

Now the project path — and thus the encoded session folder and the transcript's internal
`cwd` — are identical everywhere, regardless of username or OS. Folder B's *local* parent
still differs per machine (`/home/mistymts/.claude/...` vs `/Users/jeremy/.claude/...`); that
is fine — Syncthing pairs folders by a shared Folder **ID**, and the encoded subfolder
*inside* matches because the project path matches.

> One-time migration: move the desktop project from `~/Development/claude` to `/opt/dev/claude`
> (a `git clone`/`mv` + reopen). After that, everything keys off the neutral path.

**Linux-only alternative (not used here since we need macOS):** mirror the desktop's home
path on the laptop (`sudo mkdir -p /home/mistymts && chown`), leaving the desktop untouched.
Rejected as the default because macOS can't create `/home/...`.

**Rejected:** symlink tricks — Node/Claude resolve `realpath`, so the transcript records the
underlying real path anyway. Use a real matching directory.

## 7. Custom skills & helper scripts

**Design principle.** *Sync-wait* and *session launch* happen at the **shell** level (a small
open helper) → wrapper script. *Closeout* (summarize state, optional WIP commit, **and the
sync-close itself**) happens **inside** the session via a Claude **skill** — so syncing is
always **explicit and opt-in**, never a global hook on arbitrary `claude` exits. All scripts
are **POSIX sh**, avoiding GNU-only flags so they run on macOS's BSD userland too (use
`python3`/`jq` for parsing rather than GNU `sed`/`readlink -f`).

**Opt-in gating (two mechanisms, both honored).**
1. **Skill-scoped:** `sync-close` is invoked *only* from `/sync:stop`, never automatically
   on exit. If you close a normal session, nothing syncs.
2. **Directory-marker:** a project opts in by having a **`.claude-sync`** marker file at its
   root (created at setup). The open helper and the skill **no-op the sync** when the marker
   is absent — so they're safe to run anywhere and only act on sync-enabled projects.

### 7.1 One config file — `session_sync/config.sh`
```sh
PROJECT_DIR="/opt/dev/claude"
CODE_FOLDER_ID="claude-code"          # Syncthing folder IDs (set when pairing)
SESSION_FOLDER_ID="claude-sessions"
SYNCTHING_URL="http://127.0.0.1:8384"
# SYNCTHING_API_KEY optional; auto-detected if unset (see 7.6)
```

### 7.2 `sync-wait.sh` (shared helper)
Forces a rescan then polls the REST API until the given folders are fully synced locally.
```sh
for id in "$@"; do curl -s -H "X-API-Key:$KEY" "$URL/rest/db/scan?folder=$id" >/dev/null; done
# poll GET /rest/db/status?folder=$id until .state=="idle" && .needBytes==0 && .needItems==0
```

### 7.3 `sync-start` — the one command you run to start (open only, no exit hook)
Collapses "sync-wait → cd → resume" into a single wrapper. **Only opens** — it installs no
on-exit behavior, so it never syncs when you quit Claude.
```sh
. session_sync/config.sh
[ -f "$PROJECT_DIR/.claude-sync" ] && sync-wait.sh "$CODE_FOLDER_ID" "$SESSION_FOLDER_ID"
cd "$PROJECT_DIR"
claude --resume        # you work; closing is handled explicitly via /sync:stop
```
Install as a shell function/alias `sync-start`. Sitting down = `sync-start`. If the dir has no
`.claude-sync` marker, it skips the wait and just resumes (safe to use anywhere).

### 7.4 `sync-close.sh` (invoked by the skill, or run manually)
Force a rescan so your latest edits **and the flushed transcript** are indexed for the peer;
report status (optionally wait for the peer if it's currently online). **No-ops** if the
project has no `.claude-sync` marker.

**Ordering note.** The transcript JSONL is **appended incrementally** as the session runs, so
when `/sync:stop` calls `sync-close.sh` mid-turn, everything up to that point is already
on disk and gets synced. The only thing not captured is the skill's *own* trailing summary
line — which is fine, because `HANDOFF.md` (a synced file) carries that state. If you ever
want the byte-for-byte-complete transcript, run `sync-close.sh` once more after exiting Claude
(optional).

### 7.5 Skill: `/sync:stop` (in-session prep **and** the sync)
Plugin skill (`session_sync/skills/stop/SKILL.md`). Run it just before you switch — this
is the single explicit "hand off" action, and it performs the sync itself:
```markdown
---
name: sync-stop
description: Hand this Claude Code session off to another machine — write a handoff note,
  optionally commit WIP, and sync (code + transcript) to the peer. Use right before switching
  computers. Only syncs if the project has a .claude-sync marker.
---
1. Summarize current state into HANDOFF.md (Done / In progress / Next step).
2. Ask whether to commit WIP; if yes: `git add -A && git commit -m "wip: handoff <date>"`.
3. If a `.claude-sync` marker exists at the project root, run
   `session_sync/scripts/sync-close.sh` and report the sync status; otherwise report that
   sync is not enabled for this directory and skip it.
4. Print the resume command for the other machine (`sync-start`).
```

### 7.6 Locating the Syncthing API key portably
Order: (1) `$SYNCTHING_API_KEY` if set; else (2) parse `<apikey>` from `config.xml`, whose
path differs by OS —
- Linux: `~/.local/state/syncthing/config.xml` or `~/.config/syncthing/config.xml`
- macOS: `~/Library/Application Support/Syncthing/config.xml`

Robust: `syncthing --paths` prints the config location on both OSes; the helper reads that,
then greps the key. (Avoids hardcoding OS paths.)

## 8. Usage (the streamlined answer to "what do I actually run?")

**Per machine, when you sit down:**
```sh
sync-start           # waits for sync (if .claude-sync present), then resumes in /opt/dev/claude
```
**When you're ready to hand off / leave:**
```
/sync:stop   # writes HANDOFF.md, optionally commits WIP, AND runs the sync-close
```
Then exit Claude normally. Nothing syncs on a plain exit — sync happens **only** when you run
`/sync:stop`, and **only** in a `.claude-sync` directory.

So: **one command to open, one skill to hand off.** Normal `claude` sessions elsewhere are
completely unaffected. (`sync-wait` / `sync-close` still exist as standalone scripts for
manual/debug use.)

## 9. Failure modes & conflict handling

| Situation | Result | Mitigation |
|---|---|---|
| Same session live on both machines | `*.sync-conflict-*` on the JSONL | Always close before switching (sequential model). |
| Switch before sync finished | Stale transcript | `ccdev` blocks on `sync-wait` before resuming. |
| Peer offline when leaving | Not yet pushed | Fine — pushes on next connect; `ccdev` waits for the pull on arrival. |
| Heavy build dirs | Slow syncs | `.stignore`. |
| Code edited on both while offline | Conflict file | Resolve, commit clean state to git. |

## 10. Setup checklist (one-time)

**Both machines:** install Syncthing + jq (§4); log Claude Code in; `mkdir -p /opt/dev` +
chown (§6); place `/opt/dev/claude`.
**Syncthing:** pair the two devices; add Folder A (code, `.stignore`) with ID `claude-code`;
add Folder B (`$HOME/.claude/projects/-opt-dev-claude`) with ID `claude-sessions`; both
send-receive.
**Marker:** `touch /opt/dev/claude/.claude-sync` to opt this project into syncing.
**Install:** run `session_sync/install.sh` (installs the `sync-*` commands to `~/.local/bin`
and the `sync` plugin) on both machines.

## 11. Verification / test plan

1. Desktop: `sync-start`, make a trivial uncommitted edit, `/sync:stop` (syncs), exit.
2. Laptop: `sync-start`; confirm the session resumes and the edit is present; one turn;
   `/sync:stop`; exit.
3. Desktop: `sync-start`; confirm the laptop's turn + edits are present.
4. Verify a session in a **non**-`.claude-sync` dir does nothing on `/sync:stop` (no sync).
5. Deliberately edit both offline; confirm a `sync-conflict` file appears; verify recovery.

## 12. Open decisions

- **WIP auto-commit** in `/sync:stop`: prompt each time (default) vs. always automatic?
- **Folder B scope:** single project subfolder (recommended) vs. all of `~/.claude/projects/`.
- **Multiple projects later:** replicate the Folder A/B pair per project, or one shared
  `/opt/dev` code root with per-project session subfolders.
- **Neutral root name:** `/opt/dev` (default) vs. `/srv/dev` vs. `/Users/Shared`+`/opt` split.
