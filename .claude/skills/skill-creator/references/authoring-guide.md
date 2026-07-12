# Authoring guide — how to write the SKILL.md body

Load this in Phase 6 (Write). It encodes the rules the validator can't check
for you: how to shape instructions to the failure, how to write the description,
and how to structure files.

## Frontmatter contract (hard rules — the validator enforces these)
- Allowed keys only: `name`, `description`, `license`, `allowed-tools`,
  `metadata`, `compatibility`. Unknown keys make the skill fail to load.
- `name`: kebab-case `^[a-z0-9-]+$`, ≤64 chars, **must equal the folder name**,
  no "anthropic"/"claude".
- `description`: non-empty, ≤1024 chars, **no angle brackets** `<` `>`, third
  person ("Processes X…", not "I can help you…").

Optional-but-useful frontmatter:
- `allowed-tools`: restrict what the skill may call (e.g. read-only skills).
- `disable-model-invocation: true`: for side-effecting/manual skills (deploy,
  commit) that should only run when the user explicitly asks.
- `user-invocable: false`: background-knowledge skills not meant as `/commands`.

## The description is the activation contract
Claude reads ONLY the description to decide whether to load the skill. Two failure
modes pull in opposite directions — resolve them like this:
- **Under-triggering** (skill never fires): be *pushy on triggers*. Name the
  synonyms, symptoms, error strings, and edge contexts that should activate it.
  ("Use when the user wants to create, author, build, scaffold… a skill.")
- **Body-skipping** (agent reads the description and improvises instead of
  following the steps): be *silent on process*. Do NOT summarize the workflow in
  the description — that tempts Claude to act on the summary. State *what* and
  *when*, never *how*.
Keyword-coverage check before shipping: would the description match the way a
real user would phrase this, including a near-miss they'd expect it NOT to fire on?

## Match the form to the failure
Before writing the body, classify what kind of failure the skill exists to fix,
then use the matching form:
- **Discipline violation** (agent knows better but cuts corners) → an explicit
  prohibition + a rationalization table ("if you're tempted to think X, don't")
  + red-flag list. Explain the *why*; all-caps ALWAYS/NEVER without a reason is a
  yellow flag.
- **Wrong-shaped output** → a positive recipe / output contract / worked example.
- **Omitted element** → a REQUIRED slot in a template.
- **Conditional behavior** → predicate-keyed conditionals ("If the repo uses X, …").

## Degrees of freedom — match specificity to fragility
- **Fragile/exact operations** (a flaky command, a strict format): low freedom —
  "run exactly this, don't add flags." Consider bundling a script.
- **Open-ended tasks** (many valid paths): high freedom — principles and
  guidance, let Claude choose.
Decide this deliberately; don't default everything to prose or to rigid MUSTs.

## Progressive disclosure — keep SKILL.md lean
- Body under ~500 lines. Push detail into `references/`, `scripts/`, `assets/`,
  `agents/` and link by relative path.
- References must be **one level deep** — Claude only head-previews nested files.
- Add a table of contents to any reference file over ~100 lines.
- Provide ONE default path, not five options. Use gerund names for procedures
  (`processing-pdfs`). Forward slashes only. No time-sensitive info in the body
  (put superseded patterns in a collapsed "old patterns" section).

## Bundled scripts (if any)
- Solve, don't punt: handle errors inside the script rather than telling Claude
  to cope. No unexplained "voodoo" constants.
- For batch/destructive ops use plan → validate → execute.
- Keep the surface small — this skill ships only `scripts/validate_skill.py`.

## "Should this even be a skill?" (say no when it should be no)
If the need is a one-off, a doc lookup, or already covered by an existing skill
or a CLAUDE.md note, say so and stop. A near-duplicate that already works is a
reason to adopt/fork, not rebuild. (See Phase 0 triage.)
