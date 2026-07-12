---
name: class-overview
description: >-
  Analyze a single code object (typically a Python class) and produce a markdown
  overview of its role, responsibilities, and available resources, plus Mermaid
  diagrams — a relationship/class diagram including derived subclasses and a
  function-call and data-flow diagram — then show it for review and optionally save
  it beside the source file. Use whenever the user wants to understand, explain,
  document, summarize, map, or diagram a class or object: "explain this class",
  "what does X do", "document this class", "diagram this object", "give me an
  overview of X", "how does this class work". Reads statically; never executes the
  target code.
---

# Class Overview

Given one code object, produce a grounded, consistent markdown overview with
diagrams — then let the user review it and optionally save it next to the source.

This skill's value is **consistency, bounded scope, grounded diagrams, and a
review-before-save gate** — a capable agent already reads accurately, so the win is
making that repeatable and scoped, not merely correct. Honor the gates.

Load `references/overview-template.md` before writing (Step 4) and
`references/mermaid-guide.md` before drawing (Step 4). Reads only; the single write
happens at Step 6 and only on explicit confirmation.

---

## Step 1 — Identify the target
Resolve the object: a file path and/or class name (e.g. `path/to/worker.py Worker`).
If the class name is given without a path, locate its definition
(`grep -rn "class <Name>"`). If ambiguous (multiple matches, or a whole file with
several classes), ask which object. Read the target's own definition now — nothing
else yet.

## Step 2 — Scope gate (interactive)
Do a **bounded** discovery pass:
- **Direct collaborators** — the types the class imports/holds/calls (one hop only).
- **Derived subclasses** — scan the repo for `class X(<Target>)`, and for its
  collaborators' subclasses (e.g. subclasses of a held base type).

Present the collaborator + subclass list and ask the user, for each (or as groups),
to mark **Expand** (read and diagram in detail) / **Brief** (name and one line only)
/ **Ignore**. Default is one hop; only go deeper (transitive) if the user asks.

→ WAIT FOR USER. Do not read collaborator internals until scope is chosen.

## Step 3 — Gather grounded facts
Read the target fully, and the definitions of everything marked **Expand**. For
**Brief** items, read only the signature/docstring. Then **stop reading** — do not
pull in more files or follow further hops. Track every file you open (for the audit
trail in the template).

## Step 4 — Build the overview
Write the document using `references/overview-template.md` (exact sections, in order)
and draw both required diagrams per `references/mermaid-guide.md`:
- a `classDiagram` (relationships + derived subclasses, edges labeled by kind), and
- a `flowchart` (function-call / input / output / data-flow through the methods).
Add one optional extra diagram only if it materially helps.
Apply the grounding rules: every node/edge traces to something you read; label edge
kinds; mark dynamic/unresolved relationships dashed and list them under Open
Questions. Put anything you treated as Brief/Ignore in Open Questions so scope is
explicit. **Validate every diagram renders** before moving on — follow "Before you
present" in `mermaid-guide.md` (keep sequenceDiagram message text plain: no `;`, `[`,
`]`, `**`, or `->`; quote flowchart labels). A diagram that won't parse is worse than none.

## Step 5 — Show & confirm
Present the full overview inline to the user. Ask: **is this correct, and is anything
unclear or missing?** Revise on feedback and re-show. Do not save yet.

→ WAIT FOR USER.

## Step 6 — Offer to save
Offer to save the overview as `<ClassName>.overview.md` in the same directory as the
class's defining file. Write it **only on explicit yes**. Never modify the source
file or anything else; never commit or push. If the user declines, leave the
overview in the conversation only.

---

## Principles
- One hop by default — bounded scope beats exhaustive sprawl. Ask before going deep.
- Ground every claim and every edge in something you actually read; mark inferences.
- Same template every time, so overviews of different objects are comparable.
- Show before you save; write only what the user approves, only where they approve.
