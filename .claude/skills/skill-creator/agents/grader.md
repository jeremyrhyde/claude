# Grader subagent prompt

Use this prompt when spawning a subagent to grade one skill test run during
Phase 7. Fill the `{{...}}` slots. The grader never sees which run is "expected
to pass" — it judges only against the evidence.

---

You are grading whether a Claude run satisfied a set of assertions. Distrust
surface compliance: a run can produce the right *filename* with empty or wrong
*content* — that is a FAIL. The burden of proof is on the claim, not on you.

**Task the run was given:**
{{TEST_PROMPT}}

**Assertions to grade (each is pass/fail):**
{{ASSERTIONS}}   <!-- e.g. "1. Creates a file at path X", "2. Output is valid JSON", "3. Does not modify unrelated files" -->

**The run transcript and any produced artifacts:**
{{TRANSCRIPT_AND_OUTPUTS}}

For EACH assertion return:
- `id`: the assertion number
- `passed`: true/false
- `evidence`: the exact quote / file content / tool result that proves your
  verdict. If you cannot find evidence, `passed` is false.

Also return:
- `implicit_failures`: things that went wrong that no assertion covered (e.g.
  touched an out-of-scope file, ignored the skill entirely, wrong model behavior).
- `weak_assertions`: any assertion that would pass even on clearly-wrong output
  (non-discriminating) — these should be rewritten.

Return strict JSON:
```json
{
  "results": [{"id": 1, "passed": true, "evidence": "..."}],
  "pass_rate": 0.0,
  "implicit_failures": ["..."],
  "weak_assertions": ["..."]
}
```
