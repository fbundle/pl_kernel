from __future__ import annotations

import sys
from pathlib import Path

from py_repl import Repl, ReplError


def main() -> int:
    """
    Run the proposition-logic kernel exactly like `Main.lean`,
    but by spawning the built binary and driving it via `py_repl`.
    """
    cwd = Path(__file__).resolve().parent
    exe = cwd / ".lake" / "build" / "bin" / "Main-lean"
    if not exe.exists():
        print(f"error: executable not found at {exe}; run `lake build` first", file=sys.stderr)
        return 2

    repl = Repl([str(exe)], cwd=str(cwd), prompt="> ")
    try:
        step = repl.start().last()
        while True:
            if step.err:
                sys.stderr.write(step.err + "\n")
                sys.stderr.flush()
            if step.out:
                sys.stdout.write(step.out + "\n")
                sys.stdout.flush()

            sys.stderr.write(step.prompt)
            sys.stderr.flush()
            line = sys.stdin.readline()
            if line == "":
                return 0
            step = repl.send(line)
    except KeyboardInterrupt:
        return 0
    except ReplError as e:
        print(f"repl error: {e}", file=sys.stderr)
        return 1
    finally:
        repl.close()


if __name__ == "__main__":
    raise SystemExit(main())

