# Implementation plan template

Load in Step 7. Written to `<object>.impl-plan.md` beside the pipeline after the spec passes
review. It must be executable by a fresh agent (or you, in Step 8) with no guesswork.

---

# Impl Plan: `<object>` — `<change>`
Spec: `<object>.change-spec.md` · execution gate: **requires explicit user go-ahead**

## Ordered tasks
A totally-ordered task list. Sequence to keep the tree valid where possible (define the new
type first, then producers, then consumers, then derived objects). For each task:

### Task N — `<title>`
- **Files:** exact paths (create / modify).
- **Edit:** the concrete before → after (real code, not "update the thing"). No placeholders.
- **Depends on:** prior task numbers, if any.
- **Verify:** the exact proving command for THIS task and its expected result (from the
  spec's re-validation checklist) — e.g. `grep -n 'status == "ok"' ...` returns nothing;
  the affected test passes; the type-check is clean.

## Global re-validation (run after all tasks)
The full re-validation checklist from the spec: every affected site + consumer + each
silent-failure callout, each with its proving command. Plus a re-run of the three
verification agents on the resulting diff.

## Rollback
How to back the change out cleanly if execution reveals an unmapped consumer or a blocker
(the change may be architecturally wrong — return to the spec, don't force it through).

---

Rules: no placeholders or "etc."; every task independently verifiable; honor the spec's
resolved options exactly; do not begin execution until the user gives the go-ahead.
