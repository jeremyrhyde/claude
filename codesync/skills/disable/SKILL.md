---
name: disable
description: Disable cross-machine syncing for a project on THIS machine — removes the
  .codesync marker (pausing sync), and optionally tears down the Syncthing folders + config.
  Never touches your code or transcripts. Invoked as /codesync:disable.
disable-model-invocation: true
---

# /codesync:disable — disable session sync for a project

1. **Identify the project.** Default to the current working directory; confirm with the user
   which project they want to disable if ambiguous.

2. **Remove the marker (always).** Run `codesync disable <project-dir>`. This deletes the
   `.codesync` marker so `/codesync:stop` and `codesync start` no longer act on the project. Report
   that syncing is now paused but nothing else was changed.

3. **Ask about full teardown.** Ask whether they also want to remove the Syncthing folders and
   the session-sync config (a full opt-out). Only if they say yes, run:
   `codesync disable <project-dir> --remove-folders`
   Make clear this unregisters the two Syncthing folders and clears `config.sh`, but **does not
   delete any code or `~/.claude` transcripts** — those stay on disk.

4. **Confirm.** Summarize what was removed and note they can re-enable anytime with `/codesync:enable`.
