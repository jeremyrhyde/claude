# Explore & conform — learn the repo before generating

Load this in Step 1. The generated pipeline must look like it was written by the repo's
authors. Discover the rules; don't impose a generic template.

## What to detect (read-only)
1. **Language & layout** — the language at the construction location (Python / C++ / TS /
   …), the package/import style (how sibling modules import each other), file naming.
2. **2–3 sibling patterns** — find existing code that already does something similar (a
   pipeline, a set of typed stages, dataclass/struct packets) and read it. These are your
   templates. In pluto, e.g. `src/pipeline/scenario.py`, `src/packets/`, `src/workers/packets.py`.
3. **House conventions** — type-annotation style, `from __future__ import annotations`,
   module docstrings, error handling split (construction-plane exceptions vs run-plane
   status), immutability/`@dataclass(frozen=...)`, naming (snake_case vs camelCase).
4. **The static check command** (see below) and any linter/formatter config.

Present a short exploration summary and how you'll conform, then WAIT for the user.

## Static check-only command (the "compiles" proof — no execution)
Detect what's available and record the **guarantee level** you can achieve:

| Language | Preferred (type check) | Fallback (syntax only) |
|----------|------------------------|------------------------|
| Python   | `mypy <files>` or `pyright` | `python -m py_compile <files>` |
| C++      | `g++ -fsyntax-only -std=… <files>` or `clang++ -fsyntax-only` | compiler `-fsyntax-only` is already syntax+type |
| TS/JS    | `tsc --noEmit` | `node --check <file>` (syntax only) |

- Probe with `command -v` before relying on a tool.
- **Guarantee levels** — state which you reached, honestly:
  - **type-checked** — a real type checker ran clean (mypy/pyright/tsc/compiler).
  - **syntax-checked** — only a parser ran (e.g. `py_compile`); types were reasoned by the
    validation agents, not machine-verified. Say so explicitly.
- This is static analysis only. Never run the app, tests, or the pipeline itself — that is
  outside this skill's boundary.

## Boundary types = real types
Express each stage's Consumes/Produces as **real language types/schemas** in the repo's
idiom (Python `@dataclass`/`TypedDict`/pydantic as the repo uses; C++ `struct`), not prose.
The static check and the continuity validator both depend on this being real.

## Write boundary
Generate **only under the construction location** the user gave. Never create or modify
files elsewhere, never touch prod/secrets, never commit or push. Exploration and
validation are read-only.
