# prop-logic-kernel

This repo contains:

- `Main.lean`: a tiny proposition-logic tactic kernel wrapped in a `REPL.run` loop
- `py_prop_logic_kernel/`: the Python package you publish; it parses the kernel output into structured steps such as `goals_remaining`

## Lean code spec

The Lean kernel is defined primarily by:

- `PropLogicKernel/Basic.lean`: proposition syntax, tactics, goals, and state
- `PropLogicKernel/Parser.lean`: string parser for propositions and tactics
- `PropLogicKernel/Resolver.lean`: operational semantics for each tactic
- `PropLogicKernel/REPL.lean`: REPL transition function built on top of the resolver
- `Main.lean`: executable entrypoint

### Core data model

- A proposition `P` is one of: `⊥`, atom, conjunction `A ∧ B`, disjunction `A ∨ B`, implication `A → B`.
- A goal is a pair of:
  - a hypothesis map from natural-number names to propositions
  - a target proposition
- A state is a stack of goals plus a counter used to assign fresh hypothesis names.

### Tactic resolution rules

These are the actual rules implemented in `PropLogicKernel/Resolver.lean`.

- `intro`:
  - If the goal is `A → B`, add a fresh hypothesis `A` and replace the goal with `B`.
- `apply n`:
  - If hypothesis `n` is `A → B` and the current goal is `B`, replace the goal with `A`.
- `exact n`:
  - If hypothesis `n` is exactly the current goal `A`, solve the goal.
- `constructor`:
  - If the goal is `A ∧ B`, split it into two goals: `A` and `B`.
- `left`:
  - If the goal is `A ∨ B`, replace it with `A`.
- `right`:
  - If the goal is `A ∨ B`, replace it with `B`.
- `cases n`:
  - If hypothesis `n` is `A ∨ B`, branch into two goals: one with fresh hypothesis `A`, one with fresh hypothesis `B`.
  - If hypothesis `n` is `A ∧ B`, add fresh hypotheses `A` and `B` to the current goal.
  - If hypothesis `n` is `⊥`, solve the goal immediately.
- `lem P`:
  - Available only in classical mode.
  - Adds a fresh hypothesis `(P → ⊥) ∨ P`.
- `refine n`:
  - Available only in classical mode.
  - If hypothesis `n` is `A1 → B1` and the current goal is `B`, replace the current goal with two goals:
    - `B1 → B`
    - `A1`
- `sorry`:
  - Solves the current goal unconditionally.
- `new P`:
  - Pushes a fresh goal `P` onto the state, with an empty hypothesis map.

### Failure behavior

- If a tactic does not match the current goal or referenced hypothesis shape, resolution fails with an error message.
- `lem` and `refine` fail if classical logic is disabled.
- Any tactic other than `new` fails on an empty goal stack.

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

## Python package spec

`py_prop_logic_kernel` is a Python-only wrapper around the built Lean binary.

- `py_prop_logic_kernel.Client`:
  - starts `.lake/build/bin/Main-lean`
  - sends lines to the REPL
  - validates tactic surface syntax in Python before sending (including strict proposition parsing for `new` and `lem`)
  - parses stderr for `-- goals remaining N`
  - returns structured `Step(out, err, goals_remaining)`
- `Client.send(line)`:
  - sends any supported REPL command, including `new` and `sorry`
- `Client.send_honest(line)`:
  - like `send`, but if `new` or `sorry` appears in the input line, it does not send the command and returns a `Step` with the policy message in `err`
- `Client.init_prompt()`:
  - returns a human/AI-oriented summary of usage and tactic semantics

## AI-generated code disclaimer

The following files were written by Cursor AI:

- `README.md`
- `py_prop_logic_kernel/__init__.py`
- `py_prop_logic_kernel/client.py`
- `py_prop_logic_kernel/repl.py`
- `PropLogicKernel/Parser.lean`