# Trace protocol — bounding, disambiguation, provenance

The rules that keep a lifecycle trace accurate, bounded, and controllable. Load this
in Steps 1–4.

## Binding-kind disambiguation (do this at the def-site)
A bare name is ambiguous. Resolve the target to a single binding, then classify it —
the kind dictates *where uses live*, so it changes how you search:

| Kind | How to find its uses | Watch for |
|------|----------------------|-----------|
| **Local / parameter** | Within the enclosing function/scope only. | Name reused for a different object later in the same scope (rebind = new lifecycle). |
| **Instance attribute** (`self.x`) | Across all methods of the class, plus subclasses. | Set in one method, read/mutated in others; `__init__` is the creation site. |
| **Module global / constant** | Repo-wide references to the qualified name. | Import aliases; shadowing by locals of the same name. |
| **Object instance** | Wherever the reference is passed, stored, returned. | **Identity** — is a later value the same object, a copy, or a derived value? |

If the name resolves to more than one binding (e.g. two locals named `req` in one
function), **list the candidates with `file:line` and ask the user which one.** Never
pick silently.

## Bounded recursion (the user's core requirement)
Traversal is bounded by BOTH a numeric cap and semantic stops — **whichever hits first.**
- **Depth cap (default 2 handoff hops).** A *handoff hop* = the value crossing a
  function/method/scope boundary, or being derived into a new binding (assignment,
  `copy`, transform). Reads and mutations at the current level do NOT consume depth;
  following the value into a callee/return/store does. State the budget in the output.
- **Semantic stop-conditions (stop even before the cap):**
  1. it leaves the module / process boundary (I/O, network, persistence);
  2. it's passed into a library/framework you won't descend into;
  3. it's stored to a field/collection or returned to a caller (record the destination, stop);
  4. it goes out of scope / is reassigned / `del`eted.
- When you stop because of the cap (not a semantic stop), say so and **offer to expand
  that specific branch** — don't silently truncate.

## Coverage lenses (so destruction isn't missed)
Trace along three lenses, not just the happy path — destruction usually lives on the
second:
- **Normal** — the main create → use → mutate flow.
- **Cleanup / failure** — `finally`, `except`, context-manager `__exit__`, early
  returns; where the value is freed/reset/closed on the error path.
- **Escape / aliasing** — where a reference leaks out of scope (returned, stored on
  `self`, captured in a closure, appended to a collection), extending the real lifetime
  beyond the local scope.

## Provenance gate ([VERIFY: file:line])
Every stage, edge, and mutation claim MUST carry a `[VERIFY: file:line]` tag pointing at
the line where you actually saw it. **If you can't cite a line, don't make the claim.**
Before presenting, run a verify pass: re-open each cited `file:line` and confirm it says
what the claim says. Drop or correct anything that fails. Distinguish observed facts
from inference — mark unresolved dynamic hops (dynamic dispatch, DI, reflection,
`getattr`) as assumptions in Open Questions rather than inventing a concrete edge.
