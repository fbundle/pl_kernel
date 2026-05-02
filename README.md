# prop-logic-kernel

This repo contains:

- `Main.lean`: a tiny proposition-logic tactic kernel wrapped in an `EchoLine.loop` REPL
- `py_repl/`: a small Python package that can drive any `EchoLine.loop`-based binary via stdin/stdout/stderr
- `prop_logic_kernel.py`: a Python convenience wrapper specific to this kernel