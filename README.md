# PropLogicKernel

A propositional logic prover kernel implemented in Lean 4, featuring an interactive REPL, automated proof search, and a Python interface for automated puzzle generation and verification.

## Features

- **Lean 4 Logic Kernel**: A robust implementation of propositional logic, including:
  - Core data structures for Propositions (`P`), Tactics (`T`), Goals (`G`), and Proof States (`S`).
  - Primitive tactics: `intro`, `exact`, `apply`, `constructor`, `left`, `right`, `cases`.
  - Classical logic support via the Law of Excluded Middle (`lem`).
- **Interactive REPL**: A command-line interface for manual theorem proving.
- **Automated Prover**: An iterative deepening depth-first search (DFS) algorithm to automatically find proofs for propositional formulas.
- **Python Integration**:
  - `Client` class to interact with the Lean-based kernel.
  - Puzzle generation and verification tools.
  - Support for creating and uploading datasets to Hugging Face.

## Installation

### Prerequisites

- **Lean 4**: Install using [elan](https://github.com/leanprover/elan).
- **Python 3.10+**: Recommended to use [uv](https://github.com/astral-sh/uv) for dependency management.

### Build Lean Kernel

```bash
lake build
```

### Setup Python Environment

```bash
uv sync
```

## Usage

### Interactive REPL

You can run the Lean REPL directly:

```bash
./.lake/build/bin/Main
```

Or via the Python wrapper:

```bash
python main.py
```

### Puzzle Generation

The project includes scripts to generate random propositional logic puzzles:

```bash
python examples/generate_puzzles.py --out output --num-vars 3 --depth 5 --num-puzzles 100
```

### Puzzle Verification

Verify the generated puzzles and their proofs:

```bash
python examples/check_puzzles.py --input output
```

## Project Structure

- `PropLogicKernel/`: Core Lean 4 implementation of the logic kernel and REPL logic.
  - `Kernel.lean`: Data structures and tactic logic.
  - `Auto.lean`: Automated proof search implementation.
  - `Parser.lean` / `Printer.lean`: Serialization and deserialization of propositions and tactics.
- `REPL/`: Generic REPL framework in Lean 4.
- `py_prop_logic_kernel/`: Python package for interacting with the kernel.
- `examples/`: Scripts for batch processing, puzzle generation, and dataset management.
- `Main.lean`: Entry point for the Lean executable.
- `main.py`: Entry point for the Python-wrapped REPL.
