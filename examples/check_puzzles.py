from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


# Allow running as: `python examples/check_puzzles.py`
sys.path.insert(0, str(_repo_root()))

from py_prop_logic_kernel.puzzle import Client, load_puzzle_from_file  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Check all generated puzzles with the kernel.")
    parser.add_argument(
        "--root",
        type=str,
        default=str(_repo_root() / "output" / "prop_logic_puzzle"),
        help="Root directory containing generated puzzles.",
    )
    parser.add_argument(
        "--kernel-exe",
        type=str,
        default=str(_repo_root() / ".lake" / "build" / "bin" / "Main-lean"),
        help="Path to kernel executable.",
    )
    parser.add_argument("--limit", type=int, default=None, help="If set, only check the first N puzzle files.")
    args = parser.parse_args()

    root = Path(args.root)
    files = sorted(root.rglob("*.txt"))
    if args.limit is not None:
        files = files[: max(0, int(args.limit))]

    if not files:
        raise SystemExit(f"no puzzle files found under {root}")

    checked = 0
    with Client(exe=args.kernel_exe) as c:
        for f in files:
            puzzle = load_puzzle_from_file(f)
            c.check(puzzle)
            checked += 1
            if checked % 200 == 0:
                print(f"checked {checked}/{len(files)}")

    print(f"ok: checked {checked} puzzles")


if __name__ == "__main__":
    main()

