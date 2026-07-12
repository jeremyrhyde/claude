---
name: enable
description: Enable cross-machine Claude Code session syncing for a project on THIS machine —
  creates the Syncthing code + session folders, config, and .codesync marker, and shows how
  to pair the other machine. Run once per machine per project. Invoked as /codesync:enable.
disable-model-invocation: true
---

# /codesync:enable — enable session sync for a project

1. **Identify the project.** Default to the current working directory; if it's not a project
   root (no repo / not what the user means), ask which directory to enable.

2. **Check prerequisites.** Confirm `syncthing` is installed and the daemon is reachable
   (`curl -fsS http://127.0.0.1:8384/rest/noauth/health`). If not, tell the user to run
   `codesync/install-syncthing.sh` first, then stop.

3. **Ask about the peers.** Show *this* machine's Device ID
   (`syncthing cli show system | jq -r .myID`). Ask for the OTHER machines' Device IDs — you can
   pass **several** (2, 3, or more machines). It's optional (they can pair later), and peers are
   remembered globally, so later `codesync enable <repo>` calls reuse them with no IDs. The same
   absolute `~/…` project path is NOT required across machines; different usernames/OSes are fine.

4. **Run the enable command** (works for *any* repo — this is per-project and multi-repo safe):
   `codesync enable <project-dir> [peer-device-id …]`
   Report what it created: the two folder IDs, the encoded session path, the `.codesync` marker,
   and which peers it shared with.

5. **Explain the other machines.** On EACH other machine: install the tooling + Syncthing, clone
   the project under `~/…`, then run `codesync enable <that-project-dir> <this-machine-device-id>
   [other-peer-ids…]`. Then **accept the shared folders** on each side (Syncthing UI at
   http://127.0.0.1:8384, or `syncthing cli`). Only one machine should work in a given project at
   a time.

6. **Confirm.** Once both sides share the folders and show "Up to Date", the workflow is:
   `codesync start` (in the terminal) to begin a synced session, `/codesync:stop` to hand off.

Note: the code and session folders sync by Syncthing **Folder ID**, so the two machines can
use different local paths (`/home/<user>/…` vs `/Users/<user>/…`). The transcript records
absolute paths internally, so historical paths reference the machine they were created on;
Claude re-reads from the current directory, so continuing works.
