# Pipeline-overview template

ALWAYS produce the overview with these exact sections, in this order. Keep prose tight.
Every factual claim carries a `[VERIFY: file:line]` tag (see trace-protocol.md).

---

# `<variable>` — Pipeline Overview
`<relative/path/to/file.py>` · binding: `<local | parameter | instance-attr | module-global | object-instance>` · trace depth: `<N handoff hops>`

## Purpose
2–4 sentences: what this variable/object is *for*, and its role in the flow. Lead with a
one-line TL;DR.

## Inputs → Outputs
What goes into building it, and what comes out of using it — with the expected purpose of
each value. Two small tables:

**Inputs (what constructs it)**

| Field / source | Expression | Expected purpose | Provenance |
|----------------|-----------|------------------|-----------|

**Outputs (what its use produces)**

| Result | Derived from | Expected purpose | Provenance |
|--------|-------------|------------------|-----------|

## Creation
Where and how it is created/first bound — the def-site, with `[VERIFY: file:line]` and the
constructing expression.

## Pipeline of uses
An **ordered** list of each stage the value passes through, within the depth budget. For
each: the component/site, what it's used *for*, and any **edits/mutations** (or "read-only").
Mark the lens (normal / cleanup / escape) where relevant. Every row cites `file:line`.

1. **<site>** — <what for>; <mutation or read-only>. `[VERIFY: file:line]`
2. …

Note identity at each hop: same object, a copy, or a derived value.

## Destruction / end-of-scope
Where the value's lifetime ends — scope exit, reassignment/rebind, `del`, context-manager
exit, last reference, or object no longer referenced — with `[VERIFY: file:line]`. State
the practical last-use line and the formal end-of-scope line if they differ.

## Lifecycle Diagram
A Mermaid flowchart with **Create / Use / Mutate / Destroy** phase subgraphs (see
mermaid-guide.md). Nodes trace to real sites; edges labeled.

## Open Questions / Assumptions
Unresolved dynamic hops (dynamic dispatch, DI, reflection), identity ambiguity, aliasing
uncertainty, branches stopped at the depth cap (and offer to expand), and any inference
not backed by a `[VERIFY]` line.

## Source Files Read
Bullet list of every file consulted (relative paths) — the audit trail.
