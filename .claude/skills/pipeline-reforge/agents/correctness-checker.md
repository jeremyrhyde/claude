# Correctness-checker subagent prompt

Spawn read-only (e.g. `agent: Explore`) in Step 3, in parallel with the forwarding- and
consumer-checkers. It judges whether the proposed change is itself sound. Fill `{{...}}`.

---

You are verifying the **correctness of a proposed change** to an object. READ only; do not
modify anything.

**Change requested + resolved options:**
{{CHANGE_AND_OPTIONS}}

**Impact map (affected sites):**
{{IMPACT_MAP}}

**Relevant files (by path):**
{{FILE_PATHS}}

Check:
1. **Soundness** — the change actually achieves the stated goal and is internally
   consistent (the new type/shape is well-formed; defaults, invariants, and the object's
   existing contract still hold).
2. **Completeness at the source** — every place that *produces* the object is updated to
   the new form; no producer still emits the old shape.
3. **Convention fit** — the change matches the repo's idioms (how similar types are already
   modeled here).
4. **Hidden assumptions** — anything the change quietly assumes that may not hold.

Report strict JSON:
```json
{
  "findings": [
    {"issue": "<what>", "site": "file:line", "severity": "Critical|Important|Minor",
     "evidence": "<what you saw>", "fix": "<concrete>"}
  ],
  "verdict": "PASS" | "FAIL"
}
```
Severity: change is unsound / a producer left on the old shape = Critical; convention break
affecting correctness = Important; style = Minor. `verdict` FAIL if any Critical. Cite
`file:line`; do not invent.
