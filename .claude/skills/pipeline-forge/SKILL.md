---
name: pipeline-forge
description: >-
  Generate the code for a sequential (linear) data pipeline that implements the dataflow of
  a described object through an existing codebase: explore the repo to match its language
  and conventions, propose an ordered stage design with the object's type and format at
  each boundary for approval, then write convention-matching code and validate it with
  read-only agents (format/schema continuity, stage responsibility) plus a static
  type-check. Use whenever the user wants to build, implement, scaffold, or generate a data
  pipeline, a sequence of typed processing stages, or the flow of an object through
  create-transform-output steps in code: "build a pipeline for X", "implement a pipeline
  that ...", "scaffold stages to process X", "turn this raw input into a typed report
  through stages". Writes only under the given construction location; never executes the
  target code.
---

# Pipeline Forge

Given a construction location and a use-case, generate a **sequential** data pipeline that
implements the object's create → transform → output/destroy flow, matching the repo's
conventions, gated on an approved design and guarded by validation agents.

This skill's value is **explore-then-conform generation, a design-first approval gate,
field-level continuity + stage-responsibility guards, and a static-check guarantee** — a
capable agent already writes competent code, so the win is that you approve the shape
before code exists and that correctness is *checked against a contract*, not assumed.
Honor the gates. It is scoped to **linear** pipelines; branching/fan-out is out of scope.

Load `references/explore-and-conform.md` in Step 1 and `references/design-contract.md` in
Step 2. Validator prompts live in `agents/`. No scripts — use the repo's own type-checker.

**Boundaries:** exploration and validation are **read-only**; generation writes **only
under the construction location**; never execute the app/tests/pipeline; never commit or push.

---

## Step 1 — Intake & explore (read-only)
Resolve the **construction location** and the **object + use-case** (the desired dataflow).
Then, following `references/explore-and-conform.md`, recon the repo: detect the language,
the package/import style, 2–3 sibling patterns to model on, the house conventions, and the
available **static check command** (record the guarantee level it affords). Present a short
**exploration summary** + how you'll conform.

→ WAIT FOR USER to confirm the read of the repo.

## Step 2 — Design the pipeline (HARD approval gate)
Produce the design contract per `references/design-contract.md`: the **ordered stages** with
each stage's **Consumes / Produces** type+format and **responsibility (only-edits)**, the
**boundary types as real types** in the repo's idiom, the error planes, and — explicitly —
the **open decisions** a generator would otherwise make silently (sync vs async, which
derived values, immutability, invocation site). Present it for approval.

→ WAIT FOR USER. **Write no code until the contract is approved.** Re-confirm on revisions.

## Step 3 — Generate
Write the pipeline code **only under the construction location**, implementing the approved
contract and matching the sibling patterns: the boundary types, the ordered stages, the
runner, and the construction/run error planes. Keep to the repo's import/naming/async style.

## Step 4 — Validate against the contract
Run three checks, then fix and re-check:
1. **Read-only validator agents, in parallel** (dispatch in one message): the
   `agents/continuity-checker.md` (field-level Produces==Consumes) and
   `agents/responsibility-checker.md` (each stage edits only what it owns), each given the
   **approved contract** + generated file paths, returning Critical/Important/Minor findings.
2. **Static check** — run the detected check-only command yourself and read the exit code;
   don't trust a subagent's word. Record the **guarantee level** reached (type-checked vs
   syntax-checked — say which honestly).
3. **Fix loop** — apply the complete findings list, re-run the checks. **Block on any
   Critical**; iterate until none remain or you must surface a design problem (then return
   to Step 2).

## Step 5 — Show & confirm
Present the generated files, the validation report (findings + fixes), and the **guarantee
level** achieved. Revise on feedback and re-validate.

→ WAIT FOR USER.

## Step 6 — Finish
Summarize what was generated and where, and how to run/wire it. **Do not execute it, commit,
or push** — leave that to the user.

---

## Principles
- Sign the design, not every line — approve the stage contract before any code exists.
- Conform, don't template — generated code should look native to the repo.
- Linear only — one ordered chain; the sole invariant is Produces(N) == Consumes(N+1).
- Check against the contract, don't assume — validators + a static check, and state the
  honest guarantee level (type-checked vs syntax-checked).
- Stay in bounds — read-only explore/validate, write only under the construction location,
  never execute, never commit.
