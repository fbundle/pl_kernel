# prop-logic-kernel

This repo contains:

- `Main.lean`: a tiny proposition-logic tactic kernel wrapped in a `REPL.run` loop
- `py_repl/`: a small Python package that can drive any `REPL.run`-based binary via stdin/stdout/stderr
- `py_prop_logic_kernel/`: the Python package you publish; it parses the kernel output into structured steps such as `goals_remaining`

## REPL protocol spec (`REPL.run`)

The executable produced by `lake build` (see `.lake/build/bin/Main-lean`) implements a simple line-based protocol driven by `REPL.run` in `REPL/REPL.lean`.

Each **step**:

- **stderr (error/status stream)**: write zero or more lines of status/errors.
  - In this repo, status lines are typically prefixed with `-- ` (e.g. `-- goals remaining 2`).
- **stdout (output stream)**: write zero or more lines of “main output” (e.g. the rendered goal state).
- **stderr (prompt)**: write the prompt string (default `> `) **without** a trailing newline.
- **stdin (input)**: read exactly one line (newline-terminated). That line is passed to the transition function.

Then the next step repeats forever.

### Notes for clients

- **Do not** assume stdout and stderr are synchronized; a robust client should read both streams until it observes the prompt on stderr.
- **Flush matters**: `REPL/REPL.lean` flushes stdout/stderr after writes so subprocess-driven clients do not hang on buffered output.

## AI-generated code disclaimer

The following files were written by Cursor AI:

- `py_prop_logic_kernel/__init__.py`
- `py_prop_logic_kernel/repl.py`
- `py_repl/__init__.py`
- `py_repl/repl.py`
- `PropLogicKernel/Parser.lean`