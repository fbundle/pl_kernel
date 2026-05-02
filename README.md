# PROP-LOGIC-KERNEL

This project is a small proposition-logic tactic kernel in Lean, exposed through a line-based REPL.

## LEAN MODULE

- `PropLogicKernel/Basic.lean`: proposition syntax, tactics, goals, and state
- `PropLogicKernel/Parser.lean`: parser for propositions and tactic commands (written by cursor)
- `PropLogicKernel/Resolver.lean`: operational semantics for tactics
- `PropLogicKernel/Printer.lean`: rendering of propositions, tactics, and goals
- `PropLogicKernel/REPL.lean`: REPL-level state, status lines, and exit-code policy
- `REPL/REPL.lean`: generic line-based REPL loop
- `Main.lean`: executable entrypoint

## PROPOSITION SPECIFICATION

A proposition `P` is one of:

- `⊥`
- atom
- `A ∧ B`
- `A ∨ B`
- `A → B`

Associativity follows the parser/printer implementation:

- `∧`, `∨`, and `→` are parsed right-associatively
- parentheses may be used explicitly

## PARSER SPECIFICATION

`PropLogicKernel/Parser.lean` uppercases proposition input before parsing.

After uppercasing, proposition input is rejected unless every character is one of:

- whitespace
- `(`, `)`
- `∧`, `∨`, `→`, `⊥`
- uppercase letters `A-Z`
- digits `0-9`
- underscore `_`

Atom names are maximal nonempty strings over:

- uppercase letters `A-Z`
- digits `0-9`
- underscore `_`

Examples of valid atom names:

- `A`
- `P1`
- `HELLO_WORLD`
- `X_2`

## GOAL/STATE MODEL

A goal consists of:

- a set of hypotheses
- a target proposition

The state tracks:

- a list of goals
- `varCount`
- `newCount`
- `sorrCount`

## TACTIC

These are the kernel rules implemented by `PropLogicKernel/Resolver.lean`.

- `intro`
  - If goal is `A → B`, add a fresh hypothesis `A` and replace the goal with `B`.
- `apply n`
  - If hypothesis `n` is `A → B` and current goal is `B`, replace the goal with `A`.
- `exact n`
  - If hypothesis `n` exactly matches the current goal, solve the goal.
- `constructor`
  - If goal is `A ∧ B`, split it into two goals.
- `left`
  - If goal is `A ∨ B`, replace the goal with `A`.
- `right`
  - If goal is `A ∨ B`, replace the goal with `B`.
- `cases n`
  - If hypothesis `n` is `A ∨ B`, branch into two goals.
  - If hypothesis `n` is `A ∧ B`, add both parts as fresh hypotheses.
  - If hypothesis `n` is `⊥`, solve the goal immediately.

### CLASSICAL LOGIC

- `lem P`
  - Classical only.
  - Adds hypothesis `(P → ⊥) ∨ P`.
- `refine n`
  - Classical only.
  - If hypothesis `n` is `A1 → B1` and goal is `B`, replace the current goal with goals `B1 → B` and `A1`.

### APPLICATION LEVEL COMMANDS

- `sorry`
  - Solves the current goal unconditionally and increments `sorrCount`.
- `new P`
  - Pushes a fresh goal `P` and increments `newCount`.

## FAILURE BEHAVIOR

- Parse failures return `parse error`.
- Resolution failures return an error message and keep the previous state.
- `lem` and `refine` fail if classical logic is disabled.
- Any tactic other than `new` fails on an empty goal stack.

## REPL protocol

The executable built by `lake build` runs `REPL.run` from `REPL/REPL.lean`.

For each step:

- write zero or more status/error lines to `stderr`
- write zero or more output lines to `stdout`
- write the prompt `> ` to `stderr` with no trailing newline
- read exactly one newline-terminated line from `stdin`
- transition to the next state

Status lines are prefixed by `-- `.

Typical status line:

- `-- new_count 1 sorry_count 0 goals_remaining 2`

Success marker:

- `-- all goals accomplished!`

That success marker is emitted iff:

- at least one goal was successfully introduced via `new`
- no `sorry` was used
- all goals are solved

## EXIT CODE POLICY

At EOF, `REPL.run` returns the previous step's `code`.

`PropLogicKernel/REPL.lean` sets exit code `0` iff (same with `all goals accomplished!`):

- at least one goal was successfully introduced via `new`
- no `sorry` was used
- all goals are solved

Otherwise exit code is `1`.

Parse/resolution errors do not automatically force exit code `1`; they preserve the previous state. So if the kernel is already in a success state, a later failing command can still leave final exit code `0`.


## AI-generated code disclaimer

The following files were written by Cursor AI:

- `README.md`
- All Python code in this repo (for example: `py_prop_logic_kernel/`)
- `PropLogicKernel/Parser.lean`