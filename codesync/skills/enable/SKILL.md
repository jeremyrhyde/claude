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

3. **Ask about the peer.** Show *this* machine's Device ID
   (`syncthing cli show system | jq -r .myID`). Ask the user for the OTHER machine's Device ID
   if they have it yet — it's optional (they can pair later). Note that the same absolute
   `~/…` project path is NOT required across machines; different usernames/OSes are fine.

4. **Run the enable script:**
   `codesync enable <project-dir> [peer-device-id]`
   Report what it created: the two folder IDs, the encoded session-folder path, the config,
   and the `.codesync` marker.

5. **Explain the other side.** Tell the user to, on the OTHER machine: install the tooling +
   Syncthing, clone the project under `~/…`, then run `codesync enable <that-project-dir>
   <this-machine-device-id>`. Then **accept the two shared folders** on each side (Syncthing
   UI at http://127.0.0.1:8384, or `syncthing cli`), pointing each folder at its local path.

6. **Confirm.** Once both sides share the folders and show "Up to Date", the workflow is:
   `codesync start` (in the terminal) to begin a synced session, `/codesync:stop` to hand off.

Note: the code and session folders sync by Syncthing **Folder ID**, so the two machines can
use different local paths (`/home/<user>/…` vs `/Users/<user>/…`). The transcript records
absolute paths internally, so historical paths reference the machine they were created on;
Claude re-reads from the current directory, so continuing works.
