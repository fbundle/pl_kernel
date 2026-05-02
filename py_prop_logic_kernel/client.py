from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .repl import Repl


_GOALS_RE = re.compile(
    r"^\s*--\s*new_count\s+(\d+)\s+sorry_count\s+(\d+)\s+goals_remaining\s+(\d+)\s*$",
    re.IGNORECASE | re.MULTILINE,
)
_ALL_DONE_RE = re.compile(r"^\s*--\s*all\s+goals\s+accomplished!\s*$", re.IGNORECASE | re.MULTILINE)


@dataclass(frozen=True)
class Step:
    out: str
    err: str
    new_count: Optional[int]
    sorry_count: Optional[int]
    goals_remaining: Optional[int]
    all_goals_accomplished: bool


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
            "          `cases <n>`, `lem <prop>`, `refine <n>`\n"
            "- Hypotheses are numbered in the rendered output (for example `0: A`).\n"
            "- Status lines are on stderr (for example `-- new_count 1 sorry_count 0 goals_remaining 2`),\n"
            "  goals on stdout.\n"
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

    def new(self, new_goal: str) -> Step:
        if self._repl is None:
            raise RuntimeError("client not started; call start() first")
        line = f"new {new_goal.strip()}"
        repl_step = self._repl.step(line)
        self._last = self._to_step(repl_step.out, repl_step.err)
        return self._last

    def step(self, tactic: str) -> Step:
        if self._repl is None:
            raise RuntimeError("client not started; call start() first")

        s = tactic.strip()
        lower = s.lower()
        if ("new" in lower) or ("sorry" in lower):
            raise RuntimeError("Client.step() honesty policy: `new` and `sorry` are not allowed")

        repl_step = self._repl.step(s)
        self._last = self._to_step(repl_step.out, repl_step.err)
        return self._last

    def __enter__(self) -> "Client":
        self.start()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.finish()

    def _to_step(self, out: str, err: str) -> Step:
        all_goals_accomplished = _ALL_DONE_RE.search(err) is not None
        m = _GOALS_RE.search(err)
        if m:
            new_count: Optional[int] = int(m.group(1))
            sorry_count: Optional[int] = int(m.group(2))
            goals = int(m.group(3))
        elif all_goals_accomplished:
            new_count = self._last.new_count if self._last is not None else None
            sorry_count = self._last.sorry_count if self._last is not None else None
            goals = 0
        else:
            new_count = None
            sorry_count = None
            goals = None
        return Step(
            out=out,
            err=err,
            new_count=new_count,
            sorry_count=sorry_count,
            goals_remaining=goals,
            all_goals_accomplished=all_goals_accomplished,
        )

