# Overview template

ALWAYS produce the overview with these exact sections, in this order. Keep prose
tight — this is a comprehension aid, not exhaustive docs. Omit a section only if it
genuinely does not apply, and say why.

---

# `<ClassName>` — Overview
`<relative/path/to/file.py>`

## Role & Responsibility
2–5 sentences: what this object is *for*, the one job it owns, and — just as
important — what it deliberately does NOT do (delegated elsewhere). Lead with a
one-line TL;DR the reader can grasp before the diagrams.

## Available Resources
What the object has access to and relies on. Prefer a table:

| Name | Type | Set / obtained by | Purpose |
|------|------|-------------------|---------|

Cover instance state, injected collaborators, and helpers/modules it calls into.
Only list things confirmed by reading the source.

## Class / Relationship Diagram
A Mermaid `classDiagram` showing the target, its collaborators (per the scope the
user chose), and its **derived subclasses**. Every edge labeled by kind
(extends / composes / owns / uses / returns). See `mermaid-guide.md`.

## Function-Call & Data-Flow Diagram
A Mermaid `flowchart` of the object's methods: calls, inputs, outputs, and how data
moves through (branches, gates, up/downcasts). This is the centerpiece — make the
primary method's path readable end to end.

## Additional Diagram (optional)
Include ONE more diagram only if it materially aids understanding (e.g. a
`sequenceDiagram` of a key lifecycle). Skip if it would just repeat the above.

## Open Questions / Assumptions
List anything inferred rather than confirmed, anything dynamic the reader should
verify (duck-typed dispatch, `getattr` handlers, runtime-populated state), and
collaborators the user chose to treat as "brief" or "ignore" so scope is explicit.

## Source Files Read
Bullet list of every file consulted (relative paths). This is the reader's audit
trail and the grounding guarantee.
