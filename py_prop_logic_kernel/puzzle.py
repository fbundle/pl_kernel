from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Sequence


@dataclass(frozen=True, slots=True)
class Puzzle:
    """
    A self-contained logic puzzle: a proposition statement plus a proof script.

    - `statement` uses the same surface syntax as the kernel (`⊥`, atoms, `∧`, `∨`, `→`, parens).
    - `proof` is a sequence of REPL commands (tactics), *excluding* the initial `new <statement>`.
    """

    statement: str
    proof: Sequence[str]
    settings: Mapping[str, object] | None = None

    def as_repl_session(self) -> list[str]:
        """
        Return a runnable REPL transcript: `new <statement>` + proof lines.
        """
        return [f"new {self.statement}", *[line.rstrip("\n") for line in self.proof]]

