# Mermaid guide — lifecycle diagram + render safety

The lifecycle diagram is a Mermaid `flowchart` embedded as a code block (renders on
GitHub / VS Code / most viewers). Do not generate image files. Grounding and render
safety matter more than prettiness.

## Lifecycle grammar (Create / Use / Mutate / Destroy)
Group the flow into phase subgraphs so the create → destroy timeline reads at a glance:
```
flowchart TD
    subgraph CREATE["CREATE"]
        SRC["scenario: Scenario"] -->|"asdict"| REQ["req = WorkRequest"]
    end
    subgraph USE["USE (read-only)"]
        REQ -->|"await run(req)"| RUN["Worker.run(req)"]
        RUN -->|"read req.skill"| SPEC["lookup SkillSpec"]
    end
    subgraph DESTROY["DESTROY / end-of-scope"]
        LAST["last read"] --> REBIND["name rebound to new object"]
    end
    RUN --> LAST
```
- One node per real site; **label every edge** with the action (`read x`, `await`,
  `mutate y`, `return`, `copy`). Distinguish **read** from **mutate** in the label.
- If the value is mutated, put those sites in a `MUTATE` subgraph; if it's read-only,
  say so in the `USE` subgraph title and omit `MUTATE`.
- Keep it legible: if it exceeds ~20–25 nodes, split (e.g. one diagram per lens) rather
  than cramming.

## Grounding
Every node and edge must trace to a `[VERIFY: file:line]` you actually read. Mark dynamic
or unresolved hops dashed and annotate — `A -. "dynamic dispatch" .-> B` — and list them
in Open Questions. Never invent an edge to fill a gap.

## Pitfalls that break rendering (scan for these before presenting)
Silent killers — the diagram won't parse. Check every diagram:
1. **Quote every flowchart label containing `(` `)` `:` `,` `-` `→`:** `A["run(req): go"]`,
   `A -->|"read x"| B`. Inside quotes these characters are safe.
2. **Balanced brackets/quotes** — an unclosed `[` or `"` breaks the whole block.
3. **`subgraph` titles** with spaces/punctuation must be quoted: `subgraph U["USE (read-only)"]`.
4. **No bare `#` or unescaped `"` inside a label** — use `#quot;` / `#35;`.
5. If you also emit a `sequenceDiagram`, its message text (after `:`) must be PLAIN —
   no `;`, `[`, `]`, `**`, or `->` (they are parsed as separators/arrows). Split into
   more messages or reword.

## Before you present — validate every diagram
A diagram that won't render is worse than none. Do BOTH:
1. **Syntax scan** — walk each block against the Pitfalls list. If a Mermaid CLI is
   available (`mmdc` / `npx @mermaid-js/mermaid-cli`), parse each block and fix errors
   before showing anything; otherwise scan by hand. Cheap grep: pull every quoted label
   and confirm brackets/quotes balance.
2. **Meaning scan** — does every edge have a grounded, labeled reason? Does the timeline
   read create → use → destroy without a dead end?
Only present diagrams that pass both.
