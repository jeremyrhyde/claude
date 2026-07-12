# Mermaid guide + grounding rules

Diagrams are embedded as Mermaid code blocks in the markdown (they render on GitHub,
VS Code, and most viewers). Do not generate PNGs. Follow the grounding rules first —
they matter more than syntax.

## Grounding rules (non-negotiable)
1. **Every node and every edge must trace to something you actually read.** If you
   didn't see it in the source, it does not go in the diagram.
2. **Label every edge by its kind** so a relationship is never ambiguous:
   `extends`, `implements`, `owns`, `composes`, `uses`, `calls`, `returns`.
3. **Mark what you couldn't resolve.** Dynamic dispatch, `getattr(obj, name)`
   handlers, or duck-typed calls the source doesn't pin down → draw them dashed and
   annotate, e.g. `A -. "calls (dynamic)" .-> B`, and note it in Open Questions.
   Never invent a concrete edge to fill a gap.
4. **Keep it legible.** If a diagram would exceed ~20–25 nodes, split it (e.g. one
   relationship diagram per subtree, or separate the collaborators from the
   subclasses) rather than cramming everything into one.

## classDiagram — relationship / structure
Use for composition, inheritance, and derived subclasses.
```
classDiagram
    class Worker {
        +str worker_id
        +Model model
        +hire(model, role) None
        +run(req) WorkResponse
    }
    class Role {
        <<abstract>>
    }
    Role <|-- AnalystRole : extends
    Worker o-- Model : owns
    Worker o-- Role : owns
    Worker ..> WorkRequest : uses
```
- `<|--` inheritance · `*--` composition · `o--` aggregation/owns ·
  `..>` dependency/uses. Put `<<abstract>>` / `<<enum>>` / `<<dataclass>>`
  stereotypes on the relevant classes.

## flowchart — function-call & data flow
Use `flowchart TD`. Nodes are method calls / transforms; diamonds are branches/gates.
```
flowchart TD
    A["run(req)"] --> B["lookup skill spec"]
    B --> C{"suitable?"}
    C -- no --> R["return rejected"]
    C -- yes --> U["upcast payload to typed request"]
    U --> H["dispatch to handler"]
    H --> D["downcast response to dict"]
    D --> OK["return ok"]
```
- Quote any label containing parentheses/colons/commas: `A["foo(bar): baz"]`.
- Use `<br/>` for line breaks inside a node. Keep the primary path linear and clear.

## sequenceDiagram — lifecycle / temporal flow
Use for a key call sequence (e.g. hire → assign → run).
```
sequenceDiagram
    participant Caller
    participant W as Worker
    Caller->>W: run(req)
    W->>W: upcast payload into typed_req
    W-->>Caller: WorkResponse(ok)
```

## Pitfalls that break rendering (scan for these before presenting)
These are silent killers — the diagram simply won't parse. Check every diagram:
1. **Keep sequenceDiagram message text PLAIN.** Everything after the `:` must be a simple
   phrase — no metacharacters. In particular, banned in message text:
   - **`;`** — it is a statement separator, so `upcast x; select y` is read as two
     statements and the second fails. Split it into two message lines instead.
   - **`->` and `-->`** — read as message arrows. Write `into` / `to`, or unicode `→`.
   - **`[` `]` and `**`** — break the parse. Write `handler(a, b, extra)`, not
     `handler(a[, b][, **extra])`.
   Simple `( )` and `,` are fine (`W->>W: run(req)`). When in doubt, split into more,
   shorter messages rather than one dense line.
2. **flowchart node labels containing `(` `)` `:` `,` `-` MUST be quoted:** `A["run(req): go"]`.
   (Inside a quoted flowchart label, `;` `->` etc. are safe — the quoting protects them.)
3. **Don't put a bare `#` or unescaped `"` inside a label;** use `#quot;`/`#35;` if needed.
4. **classDiagram:** generics use `~T~` not `<T>`; keep `<<stereotype>>` on its own class line.
5. **Balanced brackets/quotes** — an unclosed `[` or `"` breaks the whole block.

Cheap self-check with no CLI: extract each sequenceDiagram's message text (the part after
`:`) and confirm none contains `;`, `[`, `]`, `**`, or `->`. That one grep catches the
most common real failure.

## Optional: color legend
If it helps, use `classDef` to distinguish roles — but keep it subtle and portable:
```
classDef target fill:#dae8fc,stroke:#6c8ebf;
classDef derived fill:#d5e8d4,stroke:#82b366;
classDef external fill:#f5f5f5,stroke:#999;
class Worker target
```
Target class = one color, its subclasses = another, external/library types = muted.

## Before you present — validate every diagram
A diagram that won't render is worse than none. Do BOTH:
1. **Syntax scan** — walk each block against the Pitfalls list above (especially the
   `->` -in-sequence-text trap and unquoted flowchart labels). If a Mermaid CLI is
   available (`mmdc` / `npx @mermaid-js/mermaid-cli`), parse each block with it and fix
   errors before showing anything; if not, do the scan by hand.
2. **Meaning scan** — does every arrow have a labeled, grounded reason? Does the primary
   flow read top to bottom without a dead end?
Only present diagrams that pass both.
