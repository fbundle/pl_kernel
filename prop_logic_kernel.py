from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from py_repl import EchoLineRepl, EchoLineReplError


_GOALS_RE = re.compile(r"^--\s*goals\s+remaining\s+(\d+)\s*$", re.IGNORECASE | re.MULTILINE)


class KernelError(RuntimeError):
    pass


@dataclass
class StepResult:
    delta: str
    goals_remaining: Optional[int]


class Kernel:
    """
    Python wrapper around the Lean REPL binary built by `lake build`.

    It communicates by writing tactic lines to stdin, then reading one "delta"
    response from stdout. The REPL prints its `"> "` prompt to stderr.
    """

    def __init__(
        self,
        exe: str | Path | None = None,
        *,
        cwd: str | Path | None = None,
    ) -> None:
        self._cwd = Path(cwd) if cwd is not None else Path(__file__).resolve().parent
        self._exe = Path(exe) if exe is not None else (self._cwd / ".lake" / "build" / "bin" / "Main-lean")
        self._repl: Optional[EchoLineRepl] = None
        self._last_delta: str = ""
        self._last_goals_remaining: Optional[int] = None

    def start(self) -> "Kernel":
        if self._repl is not None:
            return self

        if not self._exe.exists():
            raise KernelError(f"executable not found at {self._exe!s}; run `lake build` first")

        self._repl = EchoLineRepl([str(self._exe)], cwd=str(self._cwd), prompt="> ")
        self._last_delta = self._repl.start().last().delta
        self._last_goals_remaining = self._parse_goals_remaining(self._last_delta)
        return self

    def close(self) -> None:
        if self._repl is None:
            return
        self._repl.close()
        self._repl = None

    def __enter__(self) -> "Kernel":
        return self.start()

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def goals_remaining(self) -> int:
        if self._last_goals_remaining is None:
            # Before the first `new`, the banner doesn't contain a goal count.
            return 0
        return self._last_goals_remaining

    def last_delta(self) -> str:
        return self._last_delta

    def send(self, line: str) -> StepResult:
        self.start()
        assert self._repl is not None
        try:
            delta = self._repl.send(line).delta
        except EchoLineReplError as e:
            raise KernelError(str(e)) from e
        self._last_delta = delta
        self._last_goals_remaining = self._parse_goals_remaining(delta)
        return StepResult(delta=delta, goals_remaining=self._last_goals_remaining)

    # ---- tactics (one method per tactic) ----

    def intro(self) -> StepResult:
        return self.send("intro")

    def apply(self, h: int) -> StepResult:
        return self.send(f"apply {int(h)}")

    def exact(self, h: int) -> StepResult:
        return self.send(f"exact {int(h)}")

    def constructor(self) -> StepResult:
        return self.send("constructor")

    def left(self) -> StepResult:
        return self.send("left")

    def right(self) -> StepResult:
        return self.send("right")

    def cases(self, h: int) -> StepResult:
        return self.send(f"cases {int(h)}")

    def lem(self, prop: str) -> StepResult:
        return self.send(f"lem {prop}")

    def refine(self, h: int) -> StepResult:
        return self.send(f"refine {int(h)}")

    def sorry(self) -> StepResult:
        return self.send("sorry")

    def new(self, goal: str) -> StepResult:
        return self.send(f"new {goal}")

    def _parse_goals_remaining(self, delta: str) -> Optional[int]:
        m = _GOALS_RE.search(delta)
        if not m:
            return None
        return int(m.group(1))

