---
name: dataflow-trace
description: >-
  Trace the full lifecycle (pipeline) of a single variable or object through code — from
  creation, through every component that uses or mutates it, to where it is destroyed or
  goes out of scope — and produce a markdown pipeline overview: purpose notes, an
  inputs-to-outputs summary, an ordered per-stage trace with file:line provenance, and a
  Mermaid lifecycle diagram. Traversal is depth-bounded. Use whenever the user wants to
  trace, follow, or understand how a variable or object flows, is used, mutated, or
  destroyed: "trace this variable", "where does X go", "how is this object used",
  "lifecycle of X", "data flow of X", "pipeline of this variable", "what uses X". Reads
  statically; never executes the target code.
---

# Dataflow Trace

Given one variable or object, trace its create → use → mutate → destroy lifecycle and
produce a grounded, consistent **pipeline overview** with a diagram — then let the user
review it and optionally save it next to the source.

This skill's value is **controllable bounded recursion, target disambiguation, grounded
`[VERIFY: file:line]` provenance, a fixed template, and a review-before-save gate** — a
capable agent already reads accurately, so the win is making the trace repeatable,
scoped, and controllable, not merely correct. Honor the gates.

Load `references/trace-protocol.md` in Steps 1–4, `references/overview-template.md`
before writing (Step 4), and `references/mermaid-guide.md` before drawing (Step 4). Reads
only; the single write happens at Step 6 and only on explicit confirmation.

---

## Step 1 — Identify & disambiguate the target
Resolve the target to ONE binding: a name plus a location (`name@file:line`, or file +
function + name). If only a name is given, locate its definition(s)
(`grep -rn "<name>"`). Per `trace-protocol.md`:
- If the name resolves to **more than one binding** (e.g. two locals named `req` in one
  function), list the candidates with `file:line` and **ask which one** — never pick
  silently.
- Classify the **binding kind** (local/parameter, instance attribute, module global,
  object instance) at the def-site; it dictates where uses live.

→ WAIT FOR USER if the target is ambiguous.

## Step 2 — Scope & recursion gate (interactive)
State the recursion policy before tracing: **default depth 2 handoff hops** plus the
semantic stop-conditions from `trace-protocol.md`, and the three coverage lenses (normal
/ cleanup-failure / escape-aliasing). Confirm the depth with the user and offer to go
deeper on specific branches.

→ WAIT FOR USER to confirm the depth/scope.

## Step 3 — Trace the lifecycle (bounded)
From the creation site, follow the value forward hop by hop, staying within the depth
budget and honoring the semantic stops. At each site record: what it's used *for*,
whether it's read or **mutated**, the identity (same object / copy / derived), and a
`[VERIFY: file:line]` tag. Cover all three lenses so destruction/cleanup isn't missed.
When a branch is cut by the depth cap (not a semantic stop), note it for expansion.
**Then stop** — do not read beyond the budget. Track every file opened.

## Step 4 — Build the overview
Write the document using `references/overview-template.md` (exact sections, in order) and
draw the lifecycle diagram per `references/mermaid-guide.md` (Create/Use/Mutate/Destroy
subgraphs, edges labeled read vs. mutate). Apply the **provenance gate**: every stage,
edge, and mutation carries `[VERIFY: file:line]`, and a **verify pass re-reads each cited
line** before presenting; drop or fix anything uncited or unconfirmed. Mark dynamic/
unresolved hops as assumptions in Open Questions. **Validate every diagram renders**
(mermaid-guide "Before you present"). A diagram that won't parse is worse than none.

## Step 5 — Show & confirm
Present the full overview inline. Ask: **is this correct, and is anything unclear or
missing?** Revise on feedback and re-show. Do not save yet.

→ WAIT FOR USER.

## Step 6 — Offer to save
Offer to save the overview as `<variable>.pipeline.md` in the same directory as the
defining file. Write it **only on explicit yes**. Never modify the source or anything
else; never commit or push. If declined, leave the overview in the conversation only.

---

## Principles
- Bounded by policy, not by mood — state the depth + stop-conditions; expand only on ask.
- Disambiguate the target before tracing; never guess which binding was meant.
- Ground every stage and edge in a `[VERIFY: file:line]`, then re-verify; mark inferences.
- Don't miss destruction — trace the cleanup/failure and escape lenses, not just happy path.
- Same template every time; show before you save; write only what the user approves.
