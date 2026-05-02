from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Optional, Sequence

_ALL_DONE_MARKER = "all goals accomplished!"


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

    def check(self, kernel_path: str | Path = ".lake/build/bin/Main-lean") -> Optional[bool]:
        """
        Run this puzzle against the kernel binary using stdin (no REPL wrapper).

        Returns:
        - True: kernel exits with code 0 and stderr contains `all goals accomplished!`
        - False: kernel exits with nonzero code
        - None: failed to run (missing binary, timeout, or OS error)
        """
        exe = Path(kernel_path)
        if not exe.exists():
            return None

        lines = [f"new {self.statement}", *[line.rstrip("\n") for line in self.proof]]
        stdin_payload = "\n".join(lines) + "\n"

        try:
            proc = subprocess.run(
                [str(exe)],
                input=stdin_payload.encode("utf-8"),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                timeout=5.0,
            )
        except (OSError, subprocess.TimeoutExpired):
            return None

        err_text = proc.stderr.decode("utf-8", errors="replace")
        return (proc.returncode == 0) and (_ALL_DONE_MARKER in err_text)

