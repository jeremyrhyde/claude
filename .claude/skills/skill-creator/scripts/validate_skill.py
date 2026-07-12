#!/usr/bin/env python3
"""Deterministic validation gate for a SKILL.md.

Usage: python3 validate_skill.py <path-to-skill-dir-or-SKILL.md>

Checks the frontmatter and structure rules that make a skill load and trigger
correctly. Exit 0 = pass, exit 1 = failures found (printed). No third-party deps.

Rules enforced (kept in sync with references/authoring-guide.md):
  - SKILL.md exists and starts with a `---` YAML frontmatter block.
  - Frontmatter keys are limited to the known-allowed set.
  - name: required, kebab-case ^[a-z0-9-]+$, no leading/trailing/double hyphen,
    <= 64 chars, must equal the parent directory name, no reserved words.
  - description: required, non-empty, <= 1024 chars, no angle brackets (< >).
  - body: <= 500 lines (warns, does not fail, if over).
  - referenced files (references/*, scripts/*, assets/*, agents/*) that are
    linked by relative path exist and are one level deep.
"""
import os
import re
import sys

ALLOWED_KEYS = {"name", "description", "license", "allowed-tools",
                "metadata", "compatibility"}
RESERVED_IN_NAME = ("anthropic", "claude")
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def parse_frontmatter(text):
    """Return (frontmatter_dict, body_text) or (None, reason)."""
    if not text.startswith("---"):
        return None, "SKILL.md must start with a '---' frontmatter block"
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None, "frontmatter block is not closed with a second '---'"
    raw = parts[1]
    body = parts[2]
    fm = {}
    key = None
    block = False  # inside a `>`/`|` block scalar for the current key
    for line in raw.splitlines():
        m = re.match(r"^([A-Za-z0-9_-]+):\s?(.*)$", line)
        if m and not line.startswith((" ", "\t")):
            key = m.group(1)
            val = m.group(2).strip()
            # YAML block scalar indicator (>, |, >-, |-, >+, |+): value folds in
            # on the following indented lines; the indicator itself is not text.
            if re.fullmatch(r"[|>][+-]?", val):
                block = True
                fm[key] = ""
            else:
                block = False
                fm[key] = val
        elif key is not None and (block or line.startswith((" ", "\t"))):
            if not line.strip():
                continue
            fm[key] = (fm[key] + " " + line.strip()).strip()
    return fm, body


def main():
    if len(sys.argv) != 2:
        print("usage: validate_skill.py <skill-dir-or-SKILL.md>")
        return 2
    target = sys.argv[1]
    if os.path.isdir(target):
        skill_dir = target
        skill_md = os.path.join(target, "SKILL.md")
    else:
        skill_md = target
        skill_dir = os.path.dirname(os.path.abspath(skill_md))
    skill_dir = os.path.abspath(skill_dir)

    errors = []
    warnings = []

    if not os.path.isfile(skill_md):
        print(f"FAIL: no SKILL.md at {skill_md}")
        return 1

    with open(skill_md, encoding="utf-8") as fh:
        text = fh.read()

    fm, body = parse_frontmatter(text)
    if fm is None:
        print(f"FAIL: {body}")
        return 1

    # allowed keys
    for k in fm:
        if k not in ALLOWED_KEYS:
            errors.append(f"unknown frontmatter key '{k}' "
                          f"(allowed: {', '.join(sorted(ALLOWED_KEYS))})")

    # name
    name = fm.get("name", "")
    if not name:
        errors.append("name: is required")
    else:
        if not NAME_RE.match(name):
            errors.append(f"name '{name}' must be kebab-case ^[a-z0-9-]+$ "
                          "with no leading/trailing/double hyphens")
        if len(name) > 64:
            errors.append(f"name is {len(name)} chars (max 64)")
        low = name.lower()
        for w in RESERVED_IN_NAME:
            if w in low:
                errors.append(f"name must not contain reserved word '{w}'")
        parent = os.path.basename(os.path.normpath(skill_dir))
        if parent and name != parent:
            errors.append(f"name '{name}' must match parent directory "
                          f"'{parent}'")

    # description
    desc = fm.get("description", "")
    if not desc:
        errors.append("description: is required and must be non-empty")
    else:
        if len(desc) > 1024:
            errors.append(f"description is {len(desc)} chars (max 1024)")
        if "<" in desc or ">" in desc:
            errors.append("description must not contain angle brackets '<' '>'")

    # body length
    body_lines = body.strip().splitlines()
    if len(body_lines) > 500:
        warnings.append(f"body is {len(body_lines)} lines (>500) — consider "
                        "moving detail into references/")

    # referenced files exist and are one level deep
    for rel in re.findall(r"\]\(([^)]+)\)", body) + \
            re.findall(r"`(references/[^`]+|scripts/[^`]+|assets/[^`]+|agents/[^`]+)`", body):
        rel = rel.strip()
        if rel.startswith(("http://", "https://", "#", "mailto:")):
            continue
        if not re.match(r"^(references|scripts|assets|agents)/", rel):
            continue
        depth = rel.rstrip("/").count("/")
        if depth > 1:
            warnings.append(f"referenced file '{rel}' is deeper than one level "
                            "— Claude only previews one level deep")
        path = os.path.join(skill_dir, rel)
        if not os.path.exists(path):
            errors.append(f"referenced file '{rel}' does not exist")

    for w in warnings:
        print(f"WARN: {w}")
    for e in errors:
        print(f"FAIL: {e}")
    if errors:
        print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"OK: '{name}' valid ({len(warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
