# Impact analysis — bounded forward blast-radius

Load in Step 2. The goal: know exactly what a change to the object touches — before
proposing how to implement it. Read-only.

## Right-sizing first (Step 1)
Not every change deserves the full flow. Gauge blast radius quickly:
- **Trivial / mechanical / low-blast** (rename within one file, add an unused optional
  field, a comment): offer a **fast path** — a short plan + the change, skip the spec and
  the agent panel. Say why.
- **Otherwise** (touches producers + consumers, changes a type/shape, alters control
  flow): run the full flow below.

## Bounded forward trace
Start at the change site and trace the object FORWARD (creation → edits → consumers),
the inverse of debugging's backward trace. Bound it:
- **Depth 2 handoff hops** (value crossing a boundary or derived into a new binding) +
  **all direct consumers / call sites** of the changed symbol. Offer to go deeper on a
  branch; don't silently truncate.
- **Partition** what you find into **call sites** (code that produces/passes the object)
  vs **consumers** (code that reads/ingests the changed field/shape). These get different
  agents in Step 3.
- **Second-order ripples:** if a *derived* object carries the changed field forward (e.g.
  a result object set from `resp.status`), it is in scope — the change leaks one hop and
  reverts if you stop early. Follow the field, not just the symbol.
- Find sites by grep + reads (and an LSP/`find_references` if one is available). Verify
  each hit by reading it; exclude false positives (same name, different meaning) and say so.

## Bounded, ranked impact map (the output)
Do NOT dump every reference. Produce:
- **3–7 ranked findings**, most-breaking first, each: site (`file:line`), why it's
  affected, severity (Critical/Important/Minor), and what would break.
- **Silent-failure callouts** — breaks no test/compiler would catch (e.g. a stringly
  comparison that flips, a format that now prints an enum repr). These matter most.
- **A "safe / unaffected" list** — sites you checked that are NOT affected, as a trust
  signal so the reviewer knows coverage, not just risk.
- **Open implementation options** the change forces (these seed the Step 4 clarify gate) —
  frame each against the real blast radius, don't resolve them yourself.

Everything downstream (agents, spec, plan, re-validation) keys off this map.
