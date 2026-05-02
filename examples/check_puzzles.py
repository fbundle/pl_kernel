from __future__ import annotations

import argparse
import os
from multiprocessing import Pool
import sys
from pathlib import Path

from tqdm import tqdm


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


# Allow running as: `python examples/check_puzzles.py`
sys.path.insert(0, str(_repo_root()))

from py_prop_logic_kernel.puzzle import Client, load_puzzle_from_file  # noqa: E402


def _worker_check_files(args: tuple[list[str], str]) -> int:
    file_list, kernel_exe = args
    checked = 0
    with Client(exe=kernel_exe) as c:
        for fp in file_list:
            puzzle = load_puzzle_from_file(fp)
            c.check(puzzle)
            checked += 1
    return checked


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
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 1, help="Parallel workers (default: all cores).")
    args = parser.parse_args()

    root = Path(args.root)
    files = sorted(root.rglob("*.txt"))
    if args.limit is not None:
        files = files[: max(0, int(args.limit))]

    if not files:
        raise SystemExit(f"no puzzle files found under {root}")

    jobs = max(1, int(args.jobs))
    file_strs = [str(p) for p in files]

    if jobs == 1:
        checked = 0
        with Client(exe=args.kernel_exe) as c:
            for f in tqdm(file_strs, desc="checking puzzles"):
                puzzle = load_puzzle_from_file(f)
                c.check(puzzle)
                checked += 1
        print(f"ok: checked {checked} puzzles")
        return

    # Chunk files for workers
    chunk_size = max(1, (len(file_strs) + jobs - 1) // jobs)
    chunks = [file_strs[i : i + chunk_size] for i in range(0, len(file_strs), chunk_size)]

    checked = 0
    with Pool(processes=jobs) as pool:
        for n in tqdm(pool.imap_unordered(_worker_check_files, [(c, args.kernel_exe) for c in chunks]), total=len(chunks), desc="chunks"):
            checked += n

    print(f"ok: checked {checked} puzzles")


if __name__ == "__main__":
    main()

