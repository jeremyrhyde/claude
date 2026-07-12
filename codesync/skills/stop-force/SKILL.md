---
name: stop-force
description: Sync-and-close WITHOUT the handoff prep — skips writing HANDOFF.md and the
  WIP-commit prompt, and just pushes the current project's sync to the peers. Use when you want
  a quick, no-ceremony sync before switching machines. Invoked as /codesync:stop-force.
disable-model-invocation: true
---

# /codesync:stop-force — sync + close, no handoff prep

This is the express version of `/codesync:stop`. **Do NOT write HANDOFF.md and do NOT offer a
WIP commit.** Go straight to the sync:

1. Check for a `.codesync` marker at the project root:
   - If it exists, run the `codesync stop` command and report the status it prints (it rescans
     the code + session folders and pushes to each online peer).
   - If it does not exist, tell the user syncing isn't enabled for this directory and stop.

2. Remind the user: exit Claude, then on the other machine run `codesync start` to resume.

Nothing else — no notes, no commits. (Use `/codesync:stop` when you *do* want the handoff note
and optional WIP commit.)
