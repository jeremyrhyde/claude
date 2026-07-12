---
name: start
description: (Reminder) Starting a synced session is a terminal command, not an in-session
  action. Invoking /sync:start just tells the user to run `sync-start` in their shell — a skill
  can't launch/resume the session you're trying to start (you're already inside a session here).
---

# /sync:start — run it in your terminal

Starting a synced session can't be done from inside Claude — by the time this skill runs you're
already in a session, and a skill can't turn the current session into the resumed one. So do NOT
try to start, resume, or `--continue` anything yourself.

Instead, tell the user plainly:

> Starting a synced session is a **terminal** command, not a slash-command. Exit Claude and run:
>
> ```
> sync-start
> ```
>
> It waits until Syncthing is up to date, then resumes this project's session (from
> `~/.config/session-sync/config.sh` → `PROJECT_DIR`). Pass extra args through — e.g.
> `sync-start --resume` for the session picker.

Then stop.
