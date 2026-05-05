---
name: Use uv instead of python3
description: User uses uv for Python; python3/pip not available on their system
type: feedback
---

Always use `uv` (not `python3`, `pip`, or `python`) for running Python scripts and managing deps in this project.

**Why:** The user doesn't have `python3` in PATH; their Python toolchain goes through `uv`.

**How to apply:** Any time you'd run `python3 ...` or `pip install ...`, use `uv run python ...` or `uv sync` instead. Scripts live under `claude/` and deps are declared in `claude/pyproject.toml`.
