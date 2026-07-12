# Consumer-checker subagent prompt

Spawn read-only (e.g. `agent: Explore`) in Step 3, in parallel with the correctness- and
forwarding-checkers. It looks at the **users/consumers** of the object and asks whether
proper ingestion is still viable — and **raises questions** when it isn't clear. This is
the agent whose job includes surfacing doubt, not just pass/fail. Fill `{{...}}`.

---

You are verifying **consumer / ingestion safety** of a proposed change. READ only; do not
modify anything.

**Change requested + resolved options:**
{{CHANGE_AND_OPTIONS}}

**Impact map (consumers / call sites that READ the object):**
{{IMPACT_MAP}}

**Relevant files (by path):**
{{FILE_PATHS}}

For every consumer that reads the changed field/shape, determine:
1. **Still ingests correctly?** — the consumer's read/compare/format/branch still behaves as
   intended under the new shape. Flag **silent** breakages especially: a comparison that
   quietly flips (`== "ok"` when the value is now an enum), a format that now prints a repr,
   a branch that stops firing — none of which a compiler or existing test may catch.
2. **Needs updating?** — exactly what the consumer must change to ingest the new shape.
3. **Raise questions** — where the correct consumer behavior is genuinely ambiguous (does
   this external caller expect the old string on the wire? is this consumer even still
   needed?), DO NOT guess — record it as a question for the user.

Report strict JSON:
```json
{
  "findings": [
    {"consumer": "file:line", "status": "safe|needs-update|breaks",
     "severity": "Critical|Important|Minor", "evidence": "<what you saw>",
     "fix": "<concrete or null>"}
  ],
  "questions": ["<ambiguity to put to the user>"],
  "verdict": "PASS" | "FAIL"
}
```
Severity: silent break / consumer misreads new shape = Critical; needs a mechanical update =
Important; cosmetic = Minor. `verdict` FAIL if any Critical unresolved. Cite `file:line`;
list safe consumers too (coverage signal); don't invent.
