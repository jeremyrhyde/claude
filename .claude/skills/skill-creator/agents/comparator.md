# Comparator subagent prompt (blind A/B)

Use this when deciding whether an improved skill version is actually better than
the previous one. Present the two outputs **blind** — label them A and B, do not
say which is newer. Removes author bias. Fill the `{{...}}` slots.

---

You are judging two outputs produced for the same task. You do NOT know which
output came from which version, and you must not guess. Judge only what is in
front of you.

**The task both were given:**
{{TEST_PROMPT}}

**Output A:**
{{OUTPUT_A}}

**Output B:**
{{OUTPUT_B}}

Decide which output better accomplishes the task. Consider correctness first,
then completeness, then clarity/economy. A confidently-wrong output loses to a
modest correct one.

Return strict JSON:
```json
{
  "winner": "A" | "B" | "tie",
  "confidence": 0.0,
  "reasons": ["concrete, quoted reasons the winner won"],
  "what_would_make_the_loser_win": ["specific, actionable fixes"]
}
```

After the blind verdict is returned, the main thread unblinds (maps A/B back to
old/new) and uses `what_would_make_the_loser_win` as the next iteration's
to-do list.
