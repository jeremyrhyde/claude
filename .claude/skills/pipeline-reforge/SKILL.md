---
name: pipeline-reforge
description: >-
  Safely change an object that already has a pipeline. Given a change request, analyze how
  it ripples through the object's full lifecycle, call sites, and downstream consumers using
  bounded read-only agents (change correctness, forwarding/propagation, consumer ingestion),
  clarify open implementation options, then produce a specification document and — after a
  Claude self-review or your manual review passes — an implementation plan, and implement it
  only on your explicit approval. Use whenever the user wants to change, modify, refactor,
  extend, evolve, or add a field to an existing pipeline, data object, packet, or the flow
  of an object, and needs the impact/blast-radius understood first: "change X to ...", "add
  a field to ...", "refactor this pipeline", "what breaks if I change ...", "modify how X
  flows". Reads statically; writes code only after you approve the plan; never commits.
---

# Pipeline Reforge

Given an object that already has a pipeline and a change request, understand the change's
full blast radius, get the open decisions and a review from you, then plan and (on your
go-ahead) implement it. The analyze/spec/review phases are **read-only**; code is written
only after Step 7's execution gate.

This skill's value is **governed change** — bounded impact analysis, spread-out verification
agents, a clarify gate on the real open decisions, a review you control, and gated execution
with re-validation. A capable agent already finds the sites; the win is that *you* resolve
the load-bearing choices and approve before code changes. Honor the gates.

References (load per step): `references/impact-analysis.md`, `references/spec-template.md`,
`references/impl-plan-template.md`. Verification-agent prompts live in `agents/`. No scripts —
reuse the repo's own tests/type-checker.

**Boundaries:** analysis + review are read-only; code is written only under Step 8 after
explicit go-ahead, confined to the mapped sites + the two doc artifacts; never execute the
app during analysis; never commit or push.

---

## Step 1 — Intake & right-size
Resolve the **object**, its **existing pipeline** location, and the **change request** (mine
the conversation first). Then right-size per `references/impact-analysis.md`: if the change
is trivial/mechanical/low-blast, offer a **fast path** (short plan + change, skip the heavy
flow) and say why. Otherwise continue.

→ WAIT FOR USER if right-sizing is ambiguous or a fast path is offered.

## Step 2 — Impact analysis (bounded, read-only)
Following `references/impact-analysis.md`, trace the change **forward** through the object's
lifecycle, call sites, and **all direct consumers** (depth 2 + direct consumers; offer to go
deeper). Follow the field into **second-order/derived objects**. Produce the **bounded,
ranked impact map**: 3–7 findings most-breaking-first, **silent-failure callouts**, a
**safe/unaffected** list, and the **open implementation options** the change forces.

## Step 3 — Spread-out verification agents (read-only, parallel)
Dispatch the three `agents/` prompts **in one message** so they run concurrently, each given
the change + options + impact map + relevant file paths:
- `correctness-checker` — is the change itself sound and complete at every producer?
- `forwarding-checker` — does it propagate through downstream stages without being dropped/reverted/mistyped?
- `consumer-checker` — can every consumer still ingest it, and **raise questions** where unclear?
Reconcile: if agents contradict, surface it. Collect Critical/Important/Minor + the consumer
agent's **questions**.

## Step 4 — Clarify open options (gate)
Present the **open implementation options** (from the impact map + the consumer agent's
questions), each framed against the real blast radius — e.g. a load-bearing type choice. Ask
the user to resolve them. **Do not decide load-bearing choices yourself.**

→ WAIT FOR USER.

## Step 5 — Write the specification
Write `<object>.change-spec.md` beside the pipeline per `references/spec-template.md`:
change, resolved options, ranked impact map, agent findings, per-site plan of record,
migration/back-compat + performance notes, and a **re-validation checklist keyed to the
impact map**. Present it.

## Step 6 — Review gate (your choice)
Offer: **(a) Claude self-review** — spawn adversarial reviewers over the spec on
correctness/completeness, consumer-safety, and runtime-performance; or **(b) your manual
review** — present the spec + a Critical/Important/Minor triage template. Either way, **all
Critical/Important must clear** (fix the spec and re-review) before proceeding.

→ WAIT FOR USER to pick the review and to sign off.

## Step 7 — Implementation plan + execution gate
On a passed spec, write `<object>.impl-plan.md` beside the pipeline per
`references/impl-plan-template.md`: ordered, no-placeholder tasks, each with its proving
command, plus global re-validation and rollback. Present it and **ask for the go-ahead to
execute.**

→ WAIT FOR USER. **Write no code until execution is explicitly approved.**

## Step 8 — Execute & re-validate
Only on approval: implement the change across the mapped sites (only those sites). Then
**re-validate**: run the impl plan's proving commands + the repo's static check/affected
tests, and **re-run the three agents on the diff**. Apply the "don't trust agent reports"
rule — verify the outcomes yourself. **Block on any Critical**; if execution reveals an
unmapped consumer or the change looks architecturally wrong, stop and return to Step 5. Do
not commit or push. Report what changed, the re-validation results, and anything left open.

---

## Principles
- Governed change — you resolve the load-bearing options and approve before code moves.
- Read-only until approved — analysis, spec, and review write no code.
- Follow the field, not just the symbol — second-order ripples are in scope.
- Hunt silent failures — a comparison that quietly flips is worse than a compile error.
- Re-validate against the impact map — every affected site is a checklist line, verified.
