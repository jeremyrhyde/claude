---
name: sync-stop
description: Stop and hand this Claude Code session off to another machine. Writes a HANDOFF.md
  state note, optionally commits work-in-progress, and (only if the project has a .claude-sync
  marker) runs the Syncthing push so the code and this transcript are ready for the other
  machine to resume. Use right before switching computers.
---

# Sync stop (hand off)

Perform these steps in order.

1. **Write `HANDOFF.md`** at the project root — concise and skimmable, since this is the note
   "future you" reads on the other computer. Use these headings:
   - **Done** — what was completed this session
   - **In progress** — what's mid-flight, plus any context needed to continue
   - **Next** — the immediate next step to take on the other machine

2. **Offer a WIP commit.** Ask whether to commit work-in-progress. If yes, run:
   `git add -A && git commit -m "wip: handoff $(date '+%Y-%m-%d %H:%M')"`
   If the project isn't a git repo or the user declines, skip this step.

3. **Push the sync (gated).** Check for a `.claude-sync` file at the project root:
   - If it exists, run the `sync-stop` command and report the status it prints (it rescans the
     code + session folders and, if a peer device is configured and online, waits until the
     peer has received everything).
   - If it does not exist, tell the user syncing is not enabled for this directory and skip.

4. **Tell the user how to resume.** On the other machine, run `sync-start` (in the terminal) —
   it waits for the sync to land, then resumes this exact session.

Note: because Claude appends the transcript incrementally, running the sync here captures
everything up to this point; only this skill's trailing summary line won't be in the synced
transcript, which is fine because `HANDOFF.md` carries that state. For a byte-perfect
transcript, the user can optionally run the `sync-stop` command once more after exiting Claude.
