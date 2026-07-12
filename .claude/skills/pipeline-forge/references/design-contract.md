# Design contract — the linear pipeline design (approval artifact)

Load this in Step 2. This is what the user approves BEFORE any code is written. It is also
the ground-truth contract the validators check the generated code against — so it must be
concrete and typed, not hand-wavy.

Present it in this exact shape:

---

## Pipeline: `<name>`  ·  object: `<the object being pipelined>`
Construction location: `<path>` · Language: `<detected>` · Guarantee target: `<type-checked | syntax-checked>`

### Stages (ordered — the value flows top to bottom)
For each stage, one row. The core invariant is **Produces(N) == Consumes(N+1)**.

| # | Stage | Consumes (type) | Produces (type) | Responsibility (only-edits) |
|---|-------|-----------------|-----------------|-----------------------------|
| 1 | `<StageName>` | `<InType>` | `<OutType>` | what it creates/edits; what it passes through untouched |
| 2 | … | `<OutType of 1>` | `<...>` | … |
| … | | | | ends in the final output type, or an explicit destruction/sink |

### Boundary types (real, in the repo's idiom)
Define each `<Type>` as an actual dataclass/struct/schema with its fields and types — the
shapes that cross the boundaries. These become real code.

### Error planes (match the repo)
- **Construction plane** — invalid setup (empty chain, first stage's Consumes ≠ the raw
  input, last stage's Produces ≠ the final type, any adjacent mismatch): how it's signalled
  (e.g. raise a `PipelineError`).
- **Run plane** — per-item failures: surfaced as a status/result, not an exception (match
  the repo's convention).

### Open decisions (call these out for the user — don't decide silently)
List the choices a generator would otherwise make unilaterally: sync vs async, which
derived values to compute, immutability, where the pipeline is invoked from, naming. The
user resolves these at the gate.

---

Rules:
- **Strictly linear.** One totally-ordered chain; the only interfaces are adjacent
  boundaries. If the task actually needs branching/fan-out, say so — it's outside this
  skill's scope (that's system-design, not a linear pipeline).
- Ground every type in a real sibling pattern found during exploration.
- Do not proceed to generation until the user approves this contract.
