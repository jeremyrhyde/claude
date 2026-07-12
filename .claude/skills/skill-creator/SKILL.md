---
name: skill-creator
description: >-
  Author or improve a Claude Skill through a deliberate, human-in-the-loop process:
  triage whether to build/adopt/fork at all, restate the request, ask only the
  clarifying questions not already answered, research related official and community
  skills in parallel, propose a plan for confirmation, watch the task fail without a
  skill to find the real gaps, write the SKILL.md, then validate and test it with-skill
  vs. baseline until it measurably helps. Use when the user wants to create, author,
  build, design, scaffold, improve, upgrade, or fix a skill (or asks to "make a skill
  for X" / "make this skill better").
---

# Skill Creator

A meta-skill that turns an idea into a well-formed, **tested** Claude Skill — or
improves an existing one. It is **interactive by design**: move through the phases
in order and stop at each `→ WAIT FOR USER` gate. Do not write any skill file until
the Phase 4 plan is explicitly confirmed.

Writing the SKILL.md is the *middle* of this process, not the end. Two reference
files carry the detail — load them when their phase arrives:
- `references/authoring-guide.md` — how to write the body, description, frontmatter.
- `references/eval-loop.md` — baseline, validate, test-and-iterate protocol.
Subagent role prompts live in `agents/`. The only script is `scripts/validate_skill.py`.

---

## Phase 0 — Triage & intake

Before anything, mine the current conversation for intent — don't re-ask what's
already there. Then decide the shape of the work and confirm it:

- **Is this even skill-worthy?** One-off, doc lookup, or already covered by an
  existing skill / CLAUDE.md note → say so and offer to stop. (See the
  "Should this even be a skill?" note in `references/authoring-guide.md`.)
- **Create-new vs. edit-existing?** For an edit: preserve the original `name` and
  folder; if the target is a read-only installed skill, copy it to a writable
  location first; snapshot the current version as the Phase 8 baseline.
- **Adopt / fork / improve / build?** If research (or prior knowledge) shows a
  near-duplicate that already works — including the official `skill-creator`
  plugin — surface it and let the user choose to adopt or fork instead of rebuild.

→ WAIT FOR USER if the triage decision is non-obvious (skill-worthiness in doubt,
or a strong adopt/fork candidate exists). Otherwise state your read and continue.

## Phase 1 — Restate

Restate, in 1–3 sentences, what the skill is meant to do and who invokes it. Catch
misunderstandings early. No questions yet — reflect it back, then continue.

## Phase 2 — Clarify (friction-aware)

Cover three axes, but **only ask about the ones the prompt/conversation hasn't
already answered** — pre-fill the rest and present them for confirmation instead of
asking open questions. Prefer `AskUserQuestion` for choices; plain prose otherwise.

1. **How it will be used** — invoked by the user (`/name`) or auto-activated? one-shot
   or iterative? interactive or autonomous? repo-scoped or global?
2. **How it interfaces with code** — reads / writes / runs / calls services / none?
   which languages/repos? what must it NEVER touch (write boundaries, prod, secrets)?
3. **General outputs** — what does "done" look like (file/PR/diff, report, scaffold,
   side effect)? required format or destination?

Also settle success criteria, failure/edge handling, and any existing tooling to
reuse. Calibrate jargon to the user.

→ WAIT FOR USER until the three axes are pinned down.

## Phase 3 — Research related skills (hardened fan-out)

Read `references/sources.md`, then spawn **parallel subagents — one per source
cluster** (official / community lists / community collections), all dispatched in a
single message so they run concurrently. Each researcher gets a **fixed return
schema**: for every relevant skill → `repo+path` · `what it does` · `one idea worth
borrowing` · `improvements/adaptations` · `new clarifying questions`. Tell each
researcher to verify blurbs against the **actual SKILL.md**, not the list entry, and
to treat "1000+ skills" bundles as leads, not endorsements.

Then run a **synthesis checkpoint in the main thread**: dedupe overlapping findings,
sanity-check them, and produce a short briefing — related skills, ranked
improvements, and any new questions. If a near-duplicate surfaced, route back to
Phase 0 triage.

→ WAIT FOR USER on any material new questions.

## Phase 4 — Propose the plan (confirmation gate)

**First, settle the name.** If the user already gave a name for the skill in their
prompt, default to it — adopt that name as-is (only push back if it isn't valid
kebab-case, collides with an existing skill, or contains a reserved word, and even then
offer it as the first option). Otherwise, propose **3–4 candidate names** via
`AskUserQuestion` — each a distinct, descriptive, kebab-case slug that reflects the
skill's trigger (e.g. `class-overview`, `object-explainer`, `code-cartographer`), with a
one-line rationale per option. The user can always pick their own. Use the chosen name
throughout the plan below.

Then output a compact plan with these four labeled sections:
- **Expected inputs** — args, files, context, triggers the skill receives.
- **User interactions** — every point where it asks or waits.
- **Effects on code** — exactly what it reads / writes / runs, and its boundaries.
- **Outputs** — the concrete deliverable(s) and their format/destination.

Include the chosen `name`, target location (`.claude/skills/<name>/`
repo-local or `~/.claude/skills/<name>/` global), and supporting files
(`references/`, `scripts/`, `assets/`, `agents/`).

→ WAIT FOR USER. Write nothing until explicitly confirmed. Re-confirm on revisions.

## Phase 5 — Baseline: watch it fail

Before writing, establish what the skill must actually fix. Pick 1–3 realistic
prompts and spawn a **fresh subagent with no skill** to attempt one; capture what it
gets wrong or has to reinvent. That transcript — not your imagination — is the spec.
Keep the outputs as the Phase 8 comparison baseline. Skip only for pure-reference or
subjective-style skills (and say why). Details in `references/eval-loop.md`.

→ WAIT FOR USER to review the observed gaps before writing.

## Phase 6 — Write the skill

Create `<location>/<name>/SKILL.md` (+ agreed supporting dirs), following
`references/authoring-guide.md`: match the **form to the failure** observed in
Phase 5; write the **description** pushy-on-triggers / silent-on-process; pick
**degrees of freedom** by task fragility; keep the body lean with one-level-deep
references. Match conventions of skills already in the repo.

## Phase 7 — Validate

Run `python3 scripts/validate_skill.py <skill-dir>`. Fix every FAIL (frontmatter
keys, kebab-case name matching the folder, description length / no angle brackets,
referenced files exist). Re-run until it passes.

## Phase 8 — Test, iterate, finish

Follow `references/eval-loop.md`:
1. Write 2–5 discriminating pass/fail assertions per test prompt.
2. In one turn, run **with-skill vs. baseline** subagents; grade each with
   `agents/grader.md`.
3. Aggregate a benchmark table (with-skill vs. baseline pass-rate + Δ). If the skill
   isn't clearly beating baseline, fix it — it isn't earning its context yet.
4. Render a review page with the **Artifact tool** and have the user review before
   you self-critique.
5. Iterate on feedback + grader findings; re-validate after each edit; use
   `agents/comparator.md` for a **blind A/B** when deciding if v_n beats v_{n-1}.
   Optionally run the description-trigger optimization.
6. Stop when the user is satisfied / feedback is empty / a round yields no gain.

Finish: tell the user how to invoke it and where it lives (repo vs. global, symlink
for global). **Do not commit, push, or install without an explicit ask.**

---

## Principles

- Interaction gates are load-bearing — a skipped clarification produces the wrong skill.
- Watch it fail first: write to *observed* gaps, not guessed ones.
- Research before designing, and act on near-duplicates — adopt/fork beats rebuild.
- The description is the activation contract: pushy on triggers, silent on process.
- Writing the SKILL.md is the middle of the job; prove it helps before calling it done.
