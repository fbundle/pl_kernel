from __future__ import annotations

import argparse
import csv
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


def _file_key(root: Path, fp: Path) -> str:
    fp_res, root_res = fp.resolve(), root.resolve()
    try:
        return fp_res.relative_to(root_res).as_posix()
    except ValueError:
        return fp_res.as_posix()


def _load_results_csv(csv_path: Path) -> dict[str, str]:
    if not csv_path.is_file():
        return {}
    out: dict[str, str] = {}
    with csv_path.open(newline="", encoding="utf-8") as f:
        for row in csv.reader(f):
            if len(row) < 2:
                continue
            key, val = row[0].strip(), row[1].strip()
            if key == "file":
                continue
            out[key] = val
    return out


def _append_csv_row(csv_path: Path, key: str, ok: bool) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    is_new = not csv_path.is_file() or csv_path.stat().st_size == 0
    with csv_path.open("a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if is_new:
            w.writerow(["file", "correct"])
        w.writerow([key, "correct" if ok else "not_correct"])


def _check_one(client: Client, fp: str) -> tuple[str, bool, str | None]:
    try:
        puzzle = load_puzzle_from_file(fp)
        client.check(puzzle)
        return (fp, True, None)
    except Exception as e:
        return (fp, False, str(e))


def _worker_check_pairs(args: tuple[list[tuple[str, str]], str]) -> list[tuple[str, bool]]:
    pairs, kernel_exe = args
    out: list[tuple[str, bool]] = []
    with Client(exe=kernel_exe) as c:
        for fp, key in pairs:
            _path, ok, _err = _check_one(c, fp)
            out.append((key, ok))
    return out


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
    parser.add_argument(
        "--results-csv",
        type=str,
        default=str(_repo_root() / "output" / "check_results.csv"),
        help="CSV with columns file,correct — rows already present are skipped (resume).",
    )
    args = parser.parse_args()

    root = Path(args.root)
    files = sorted(root.rglob("*.txt"))
    if args.limit is not None:
        files = files[: max(0, int(args.limit))]

    if not files:
        raise SystemExit(f"no puzzle files found under {root}")

    csv_path = Path(args.results_csv)
    done = _load_results_csv(csv_path)

    file_strs: list[str] = []
    keys: list[str] = []
    for p in files:
        file_strs.append(str(p))
        keys.append(_file_key(root, p))

    pending: list[tuple[str, str]] = []
    for fp, key in zip(file_strs, keys, strict=True):
        if key not in done:
            pending.append((fp, key))

    jobs = max(1, int(args.jobs))

    if pending:
        if jobs == 1:
            with Client(exe=args.kernel_exe) as c, tqdm(
                total=len(pending), desc="checking puzzles", unit="puzzle"
            ) as pbar:
                for fp, key in pending:
                    _path, ok, _err = _check_one(c, fp)
                    _append_csv_row(csv_path, key, ok)
                    pbar.update(1)
        else:
            chunk_size = max(1, (len(pending) + jobs - 1) // jobs)
            chunks = [pending[i : i + chunk_size] for i in range(0, len(pending), chunk_size)]

            with Pool(processes=jobs) as pool, tqdm(
                total=len(pending), desc="checking puzzles", unit="puzzle"
            ) as pbar:
                for batch in pool.imap_unordered(_worker_check_pairs, [(ch, args.kernel_exe) for ch in chunks]):
                    for key, ok in batch:
                        _append_csv_row(csv_path, key, ok)
                        pbar.update(1)

    final = _load_results_csv(csv_path)
    corpus_keys = keys
    missing = [k for k in corpus_keys if k not in final]
    not_correct = [k for k in corpus_keys if final.get(k) == "not_correct"]

    if missing:
        print(f"warning: {len(missing)} puzzle(s) have no CSV row (expected after a full run)")

    n_skip = len(file_strs) - len(pending)
    if pending:
        print(f"checked {len(pending)} new puzzle(s); skipped {n_skip} already in {csv_path}")
    else:
        print(f"no pending puzzles ({n_skip} already in {csv_path})")

    if not_correct:
        print(f"fail: {len(not_correct)} / {len(corpus_keys)} marked not_correct in CSV")
        raise SystemExit(1)

    print(f"ok: all {len(corpus_keys)} puzzle(s) in corpus marked correct in CSV")


if __name__ == "__main__":
    main()
