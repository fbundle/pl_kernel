from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .repl import Repl


_GOALS_RE = re.compile(r"^\s*--\s*goals\s+remaining\s+(\d+)\s*$", re.IGNORECASE | re.MULTILINE)
_ALL_DONE_RE = re.compile(r"^\s*--\s*all\s+goals\s+accomplished!\s*$", re.IGNORECASE | re.MULTILINE)
_INT_RE = re.compile(r"^[0-9]+$")


def _is_forbidden_honest_tactic(line: str) -> bool:
    s = line.strip().lower()
    return ("sorry" in s) or ("new" in s)


class _PropParseError(ValueError):
    pass


def _skip_ws(s: str, i: int) -> int:
    n = len(s)
    while i < n and s[i].isspace():
        i += 1
    return i


def _parse_unary(s: str, i: int) -> int:
    i = _skip_ws(s, i)
    if i >= len(s):
        raise _PropParseError("unexpected end of input")
    ch = s[i]
    if ch == "⊥":
        return i + 1
    if ch == "(":
        j = _parse_imp(s, i + 1)
        j = _skip_ws(s, j)
        if j >= len(s) or s[j] != ")":
            raise _PropParseError("missing ')'")
        return j + 1
    if ch.isalpha():
        j = i + 1
        while j < len(s) and s[j].isalpha():
            j += 1
        return j
    raise _PropParseError(f"unexpected character {ch!r}")


def _parse_and(s: str, i: int) -> int:
    i = _parse_unary(s, i)
    i = _skip_ws(s, i)
    if i < len(s) and s[i] == "∧":
        return _parse_and(s, i + 1)  # right-assoc, matching Lean parser
    return i


def _parse_or(s: str, i: int) -> int:
    i = _parse_and(s, i)
    i = _skip_ws(s, i)
    if i < len(s) and s[i] == "∨":
        return _parse_or(s, i + 1)  # right-assoc
    return i


def _parse_imp(s: str, i: int) -> int:
    i = _parse_or(s, i)
    i = _skip_ws(s, i)
    if i < len(s) and s[i] == "→":
        return _parse_imp(s, i + 1)  # right-assoc
    return i


def _prop_is_valid_strict(prop: str) -> tuple[bool, str]:
    """
    Strictly validate proposition syntax (must consume full input).
    Mirrors the Lean parser behavior but rejects trailing garbage.
    """
    try:
        j = _parse_imp(prop, 0)
        j = _skip_ws(prop, j)
        if j != len(prop):
            return False, f"trailing input at position {j}"
        return True, ""
    except _PropParseError as e:
        return False, str(e)


def _tactic_is_valid_strict(line: str) -> tuple[bool, str]:
    """
    Validate tactic surface syntax in Python before sending to Lean.
    This only checks shape, not whether it applies to the current goal.
    """
    s = line.strip()
    if s == "":
        return True, ""
    if s in {"intro", "constructor", "left", "right", "sorry"}:
        return True, ""

    def one_nat(prefix: str) -> tuple[bool, str]:
        if not s.startswith(prefix):
            return False, ""
        rest = s[len(prefix) :].strip()
        if rest == "" or not _INT_RE.match(rest):
            return False, f"expected Nat after {prefix.strip()!r}"
        return True, ""

    for pref in ("apply ", "exact ", "cases ", "refine "):
        ok, msg = one_nat(pref)
        if ok or msg:
            return ok, msg

    if s.startswith("new "):
        ok, msg = _prop_is_valid_strict(s[4:].strip())
        return (ok, msg if ok else f"invalid proposition for `new`: {msg}")
    if s.startswith("lem "):
        ok, msg = _prop_is_valid_strict(s[4:].strip())
        return (ok, msg if ok else f"invalid proposition for `lem`: {msg}")

    return False, "unknown tactic"


@dataclass(frozen=True)
class Step:
    out: str
    err: str
    goals_remaining: Optional[int]


class Client:
    """
    Customized client for this proposition-logic kernel.
    """

    def __init__(
        self,
        *,
        cwd: str | Path | None = None,
        exe: str | Path | None = None,
        prompt: str = "> ",
    ) -> None:
        self._cwd = Path(cwd) if cwd is not None else Path(__file__).resolve().parents[1]
        self._exe = Path(exe) if exe is not None else (self._cwd / ".lake" / "build" / "bin" / "Main-lean")
        self._prompt = prompt
        self._repl: Optional[Repl] = None
        self._last: Optional[Step] = None
        self._graceful_exit_code: Optional[int] = None

    def init_prompt(self) -> str:
        return (
            "Prop logic kernel REPL usage:\n"
            "- Add a goal: `new <prop>` (example: `new A → A`)\n"
            "- Tactics: `intro`, `apply <n>`, `exact <n>`, `constructor`, `left`, `right`,\n"
            "          `cases <n>`, `lem <prop>`, `refine <n>`, `sorry`\n"
            "- Hypotheses are numbered in the rendered output (for example `0: A`).\n"
            "- Status lines are on stderr (for example `-- goals remaining 2`), goals on stdout.\n"
            "- This package ships Python only; build the Lean binary locally with `lake build`.\n"
            "- Tactic semantics:\n"
            "  - `intro`: if goal is `A → B`, add fresh hypothesis `A` and change goal to `B`.\n"
            "  - `apply n`: if hypothesis `n` is `A → B` and current goal is `B`, change goal to `A`.\n"
            "  - `exact n`: if hypothesis `n` exactly matches the current goal `A`, solve the goal.\n"
            "  - `constructor`: if goal is `A ∧ B`, split into two goals `A` and `B`.\n"
            "  - `left`: if goal is `A ∨ B`, change goal to `A`.\n"
            "  - `right`: if goal is `A ∨ B`, change goal to `B`.\n"
            "  - `cases n`: if hypothesis `n` is `A ∨ B`, branch into two goals; if `A ∧ B`, add both parts;\n"
            "    if `⊥`, solve the goal immediately.\n"
            "  - `lem P`: in classical mode only, add hypothesis `(P → ⊥) ∨ P`.\n"
            "  - `refine n`: in classical mode only, if hypothesis `n` is `A → B1` and goal is `B`,\n"
            "    produce goals `B1 → B` and `A`.\n"
            "  - `sorry`: solve the current goal unconditionally.\n"
            "  - `new P`: push a fresh goal `P` onto the goal stack.\n"
        )

    def start(self) -> Step:
        if self._repl is not None:
            raise RuntimeError("client already started")
        if not self._exe.exists():
            raise FileNotFoundError(f"executable not found at {self._exe!s}; run `lake build` first")
        self._graceful_exit_code = None
        self._repl = Repl([str(self._exe)], cwd=str(self._cwd), prompt=self._prompt)
        repl_step = self._repl.start()
        self._last = self._to_step(repl_step.out, repl_step.err)
        return self._last

    def finish(self, *, timeout_s: float = 2.0) -> Optional[int]:
        if self._repl is None:
            raise RuntimeError("client not started; call start() first")
        code = self._repl.finish(timeout_s=timeout_s)
        self._graceful_exit_code = code
        self._repl = None
        return code

    def graceful_exit_code(self) -> Optional[int]:
        return self._graceful_exit_code

    def last(self) -> Step:
        if self._last is None:
            raise RuntimeError("client has no steps yet; call start() first")
        assert self._last is not None
        return self._last

    def send(self, line: str) -> Step:
        if self._repl is None:
            raise RuntimeError("client not started; call start() first")

        ok, msg = _tactic_is_valid_strict(line)
        if not ok:
            current_goals = self._last.goals_remaining if self._last is not None else None
            self._last = Step(out="", err=f"python parse error: {msg}", goals_remaining=current_goals)
            return self._last

        repl_step = self._repl.step(line)
        self._last = self._to_step(repl_step.out, repl_step.err)
        return self._last

    def send_honest(self, line: str) -> Step:
        if _is_forbidden_honest_tactic(line):
            current_goals = self._last.goals_remaining if self._last is not None else None
            self._last = Step(
                out="",
                err="honesty policy: `new` and `sorry` are not allowed in send_honest",
                goals_remaining=current_goals,
            )
            return self._last
        return self.send(line)

    def __enter__(self) -> "Client":
        self.start()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.finish()

    def _to_step(self, out: str, err: str) -> Step:
        m = _GOALS_RE.search(err)
        if m:
            goals = int(m.group(1))
        elif _ALL_DONE_RE.search(err):
            goals = 0
        else:
            goals = None
        return Step(out=out, err=err, goals_remaining=goals)

