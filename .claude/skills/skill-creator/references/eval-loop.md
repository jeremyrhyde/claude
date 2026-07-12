# Eval loop — baseline, test, iterate

Load this in Phases 6–8. The core idea from every serious meta-skill: **writing
the SKILL.md is the middle of the process, not the end.** You write to fix
*observed* failures, then prove the skill actually helps.

This harness is driven by subagents + the `agents/*.md` role prompts + the
Artifact tool. The only bundled script is `scripts/validate_skill.py`.

## A. Baseline first — "watch it fail" (Phase 6, before writing)
Never write the skill from imagination. After the plan is confirmed:
1. Pick 1–3 realistic prompts that represent the task the skill is for.
2. Spawn a **fresh subagent with NO skill** and give it one such prompt.
3. Capture what it does wrong / lacks / has to reinvent. That transcript is your
   spec: the skill must fix *these observed gaps*, not hypothesized ones.
4. Keep the baseline outputs — they are the comparison set for Phase 8.

Exception: pure-reference / knowledge skills and subjective-style skills don't
need a pressure test. Skip the baseline for those and note why.

## B. Write assertions (Phase 7)
For each test prompt, write 2–5 pass/fail assertions describing what a good run
must do — concrete and *discriminating* (would fail on wrong output). Examples:
"creates a file at ./out/report.md", "output is valid JSON", "does not modify
files outside the target dir". Store them alongside the skill while iterating
(e.g. an `evals/` scratch dir); exclude `evals/` from any packaged artifact.

## C. Run with-skill vs. baseline (Phase 8)
For each test prompt, in the SAME turn, spawn two isolated subagents:
- **with-skill**: instructed to use the skill under test.
- **baseline**: the Phase-A no-skill run (reuse it, or re-run for freshness).
Then spawn a **grader** subagent per run using `agents/grader.md`, passing the
assertions + transcript + produced artifacts. The grader distrusts surface
compliance and returns per-assertion evidence.

## D. Benchmark table
Aggregate grader results into a small table the human can read at a glance:

| prompt | with-skill pass-rate | baseline pass-rate | Δ | notes |
|--------|---------------------|--------------------|---|-------|

If with-skill isn't clearly beating baseline, the skill isn't earning its
context — fix the skill (or conclude it isn't needed).

## E. Human review via Artifact
Render the runs + benchmark as an HTML review page using the **Artifact tool**
(no bundled generator needed): show, side by side, the prompt, baseline output,
with-skill output, and per-assertion verdicts with evidence. Ask the user to
review before you self-critique — their reaction is the highest-signal feedback.

## F. Iterate
Read the feedback + grader `implicit_failures` + `weak_assertions`. Improve the
SKILL.md, rewrite weak assertions, and re-run. When comparing v_n against
v_{n-1}, use `agents/comparator.md` for a **blind A/B** so author bias doesn't
decide. Stop when the user is satisfied, feedback is empty, or a round yields no
gain. Re-run the validator after every edit.

## G. Optional — description-trigger optimization
If correct triggering is critical, generate ~20 realistic queries: 8–10 that
SHOULD trigger the skill and 8–10 near-misses that SHOULD NOT. Split into
train/held-out. Try description variants, keep the one that best separates
should/shouldn't on the **held-out** set (guards against overfitting). Heavy —
offer it, don't force it.

## H. Finish
- Run `scripts/validate_skill.py <skill-dir>` one last time — must pass.
- Tell the user how to invoke it (`/<name>` or the auto-activation trigger).
- Note install/placement (project `.claude/skills/` vs. `~/.claude/skills/`,
  symlink for global). Do NOT commit, push, or install without an explicit ask.
