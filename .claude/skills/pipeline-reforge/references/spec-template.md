# Change specification template

Load in Step 5. Written to `<object>.change-spec.md` beside the pipeline's defining file,
on user approval. It is the reviewed contract the implementation plan and re-validation key
off — concrete, not hand-wavy.

---

# Change Spec: `<object>` — `<one-line change>`
Pipeline: `<path>` · blast radius: `<Critical|Important|Minor>` · guarantee target: `<type-checked | syntax-checked | tests>`

## Change requested
What the user asked for, restated precisely, and the desired end state of the object.

## Resolved implementation options
Each open option from impact analysis and the user's Step-4 decision (e.g. `Enum` vs
`StrEnum`), with the one-line reason. These are settled here — the plan must honor them.

## Impact map (ranked)
The bounded 3–7 ranked findings from `impact-analysis.md`: each site (`file:line`), why
affected, severity, what breaks — **silent failures flagged**. Then the **safe/unaffected**
list.

## Verification agent findings
The reconciled Critical/Important/Minor findings from the three Step-3 agents
(correctness · forwarding · consumer-ingestion), including any **questions the consumer
agent raised** that the user answered.

## Plan of record (per affected site)
For each affected site, the intended edit — before → after — grouped producers then
consumers then second-order/derived objects. No placeholders.

## Migration / back-compat & performance
Breaking-change assessment, any data/shape migration, backward-compat notes, and the
runtime-performance impact (added passes/copies/complexity — usually none; say so).

## Re-validation checklist (keyed to the impact map)
One check per affected site + each consumer + the silent-failure callouts, each with a
concrete proving command (repo tests / type-check / a grep gate / a deterministic run).
This is what Step 8 runs after implementing.
