from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


# Allow running as: `python examples/generate_puzzles.py`
sys.path.insert(0, str(_repo_root()))

from py_prop_logic_kernel.generate import GenerateSettings, generate_puzzle  # noqa: E402
from py_prop_logic_kernel.puzzle import Puzzle  # noqa: E402


def _write_puzzle_file(path: Path, puzzle: Puzzle) -> None:
    lines = [f"new {puzzle.statement}", *[str(x).rstrip("\n") for x in puzzle.proof]]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_examples(out_config_dir: Path, *, num_vars: int, depth: int, n: int, kernel_exe: Path | None) -> None:
    out_config_dir.mkdir(parents=True, exist_ok=True)

    for i in range(n):
        seed = num_vars * 1_000_000 + depth * 1_000 + i
        puzzle = generate_puzzle(GenerateSettings(num_vars=num_vars, depth=depth, seed=seed))
        out_path = out_config_dir / f"{i + 1:04d}.txt"
        _write_puzzle_file(out_path, puzzle)

        if kernel_exe is not None:
            ok = puzzle.check(kernel_path=kernel_exe)
            if ok is not True:
                raise RuntimeError(f"kernel check failed for {out_path} (result={ok})")


def main() -> None:
    out_dir = _repo_root() / "output" / "prop_logic_puzzle"
    cwd = _repo_root()

    parser = argparse.ArgumentParser(description="Generate proposition-logic puzzles dataset.")
    parser.add_argument("--min-vars", type=int, default=4)
    parser.add_argument("--max-vars", type=int, default=20)
    parser.add_argument("--min-depth", type=int, default=6)
    parser.add_argument("--max-depth", type=int, default=100)
    parser.add_argument("--examples-per-config", type=int, default=100)
    parser.add_argument(
        "--check-kernel",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Verify each generated file by running the built kernel once on it.",
    )
    parser.add_argument(
        "--kernel-exe",
        type=str,
        default=None,
        help="Path to kernel executable (default: .lake/build/bin/Main-lean).",
    )
    parser.add_argument("--kernel-timeout-s", type=float, default=60.0)
    parser.add_argument(
        "--num-vars",
        type=int,
        default=None,
        help="If set, only generate this single num_vars config.",
    )
    parser.add_argument("--depth", type=int, default=None, help="If set, only generate this single depth.")
    args = parser.parse_args()

    min_vars, max_vars = args.min_vars, args.max_vars
    min_depth, max_depth = args.min_depth, args.max_depth
    examples_per_config = args.examples_per_config
    exe = Path(args.kernel_exe) if args.kernel_exe is not None else (cwd / ".lake" / "build" / "bin" / "Main-lean")
    kernel_exe = exe if args.check_kernel else None

    if args.num_vars is not None or args.depth is not None:
        num_vars = args.num_vars if args.num_vars is not None else min_vars
        depth = args.depth if args.depth is not None else min_depth
        out_config_dir = out_dir / f"example_num_vars{num_vars}_depth{depth}"
        print(f"writing {out_config_dir}/0001.txt.. (num_vars={num_vars}, depth={depth}, n={examples_per_config})")
        _write_examples(out_config_dir, num_vars=num_vars, depth=depth, n=examples_per_config, kernel_exe=kernel_exe)
        return

    for num_vars in range(min_vars, max_vars + 1):
        for depth in range(min_depth, max_depth + 1):
            out_config_dir = out_dir / f"example_num_vars{num_vars}_depth{depth}"
            print(f"writing {out_config_dir}/0001.txt.. (num_vars={num_vars}, depth={depth}, n={examples_per_config})")
            _write_examples(out_config_dir, num_vars=num_vars, depth=depth, n=examples_per_config, kernel_exe=kernel_exe)


if __name__ == "__main__":
    main()

