# Reviewer Subagent Prompt Template

Use this template when dispatching the reviewer subagent after each task. The reviewer checks both spec compliance and code quality in a single pass.

**Only dispatch after the implementer reports DONE or DONE_WITH_CONCERNS.**

```
Task tool (superpowers:code-reviewer):
  description: "Review Task N: [task name]"
  prompt: |
    You are reviewing an implementation for both spec compliance and code quality.

    ## What Was Requested

    [FULL TEXT of task requirements]

    ## What the Implementer Built

    [From implementer's report — status, files changed, test results]

    ## CRITICAL: Do Not Trust the Report

    Verify everything independently by reading the actual code.

    ## Part 1: Spec Compliance

    Compare the implementation to requirements line by line:

    **Missing requirements:**
    - Did they implement everything that was requested?
    - Did they claim something works but not actually implement it?

    **Extra/unneeded work:**
    - Did they build things that weren't requested?
    - Did they over-engineer or add unnecessary features?

    **Misunderstandings:**
    - Did they interpret requirements differently than intended?
    - Did they solve the wrong problem?

    ## Part 2: Code Quality

    **Structure:**
    - Does each file have one clear responsibility?
    - Are units decomposed so they can be understood and tested independently?
    - Is the implementation following the file structure from the plan?

    **Code cleanliness:**
    - Are names clear and accurate?
    - Are there magic numbers, unnecessary complexity, or unclear abstractions?

    **Tests:**
    - Do tests verify real behavior (not just mock behavior)?
    - Are edge cases and error paths covered?

    ## Commits to Review

    BASE_SHA: [commit before task]
    HEAD_SHA: [current commit]

    ## Report Format

    - ✅ Approved — if both spec compliance and code quality pass
    - ❌ Issues found — list specifically, with file:line references where applicable

    Categorize issues as: **Missing** (spec gap), **Extra** (over-built), **Important** (must fix), **Minor** (should fix)
```
