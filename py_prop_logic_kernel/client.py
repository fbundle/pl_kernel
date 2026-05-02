from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .repl import Repl


_GOALS_RE = re.compile(r"^\s*--\s*goals\s+remaining\s+(\d+)\s*$", re.IGNORECASE | re.MULTILINE)


def _is_forbidden_honest_tactic(line: str) -> bool:
    s = line.strip().lower()
    return ("sorry" in s) or ("new" in s)


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

    def start(self) -> "Client":
        if self._repl is not None:
            return self
        if not self._exe.exists():
            raise FileNotFoundError(f"executable not found at {self._exe!s}; run `lake build` first")
        self._repl = Repl([str(self._exe)], cwd=str(self._cwd), prompt=self._prompt).start()
        last = self._repl.last()
        self._last = self._to_step(last.out, last.err)
        return self

    def close(self) -> None:
        if self._repl is None:
            return
        self._repl.close()
        self._repl = None

    def last(self) -> Step:
        if self._last is None:
            self.start()
        assert self._last is not None
        return self._last

    def send(self, line: str) -> Step:
        self.start()
        assert self._repl is not None
        repl_step = self._repl.send(line)
        self._last = self._to_step(repl_step.out, repl_step.err)
        return self._last

    def send_honest(self, line: str) -> Step:
        if _is_forbidden_honest_tactic(line):
            raise ValueError("send_honest does not allow `new` or `sorry`")
        return self.send(line)

    def _to_step(self, out: str, err: str) -> Step:
        m = _GOALS_RE.search(err)
        goals = int(m.group(1)) if m else None
        return Step(out=out, err=err, goals_remaining=goals)

