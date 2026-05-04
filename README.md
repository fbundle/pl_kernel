# PropLogicKernel: A Formal Propositional Logic System in Lean 4

PropLogicKernel is a formally verified kernel for propositional logic, implemented in **Lean 4**. It provides a foundational infrastructure for goal-directed natural deduction, automated theorem proving, and interactive proof development.

## Core Calculus and Formal Semantics

The system is built upon a tactic-based natural deduction framework. It supports both intuitionistic and classical propositional logic.

### Syntax
The language of propositions $\mathcal{P}$ is defined inductively:
- **Bottom ($\bot$)**: The contradiction `fals`.
- **Variables**: Atomic propositions defined by strings.
- **Conjunction ($A \wedge B$)**: `and(A, B)`.
- **Disjunction ($A \vee B$)**: `or(A, B)`.
- **Implication ($A \to B$)**: `imp(A, B)`.

### Proof State and Goals
A **Goal** $G$ is a pair $\langle \Gamma, \phi \rangle$, where $\Gamma$ is a context of hypotheses (a mapping from indices to propositions) and $\phi \in \mathcal{P}$ is the target proposition. The **Proof State** $S$ is a stack of goals $[G_1, G_2, \dots, G_n]$. A theorem is considered formally proven when the stack is empty.

### Tactic Semantics
Tactics $T$ define state transitions $S \xrightarrow{T} S'$. The kernel implements the following inference rules:

| Tactic | Logical Rule | Operational Semantics |
| :--- | :--- | :--- |
| `intro` | $\to$-Introduction | Introduces hypothesis $A$ from goal $A \to B$. |
| `exact n` | Hypothesis Application | Resolves goal $\phi$ if $\Gamma[n] = \phi$. |
| `apply n` | $\to$-Elimination (Backward) | Reduces goal $B$ to $A$ given $\Gamma[n] = A \to B$. |
| `constructor`| $\wedge$-Introduction | Splits goal $A \wedge B$ into subgoals $A$ and $B$. |
| `left`/`right` | $\vee$-Introduction | Reduces goal $A \vee B$ to $A$ or $B$. |
| `cases n` | Elimination Rules | <ul><li>**$\vee$-Elim**: Splits into cases for $A$ and $B$.</li><li>**$\wedge$-Elim**: Extracts $A$ and $B$ from $A \wedge B$.</li><li>**$\bot$-Elim**: Resolves any goal from a contradiction.</li></ul> |
| `lem p` | Excluded Middle | Introduces $\neg p \vee p$ (Classical Logic). |

## Automated Theorem Proving

The kernel includes an automated solver (`Auto.lean`) based on **Iterative Deepening Depth-First Search (ID-DFS)**. This strategy ensures completeness for the propositional fragment while managing the search space of proof trees. The solver explores all available tactic applications, prioritizing those that resolve goals immediately or reduce complexity.

## Implementation Details

The project is structured into modular Lean 4 components:
- **`PropLogicKernel/Kernel.lean`**: The core logical kernel defining the inductive types and transition rules.
- **`PropLogicKernel/Auto.lean`**: The automated search engine and tactic discovery logic.
- **`PropLogicKernel/Parser.lean`**: A functional parser combinator implementation for serialized propositions and tactics.
- **`PropLogicKernel/Printer.lean`**: A precedence-aware formatter for human-readable logical expressions.

## Build and Interaction

To build the Lean kernel and REPL:
```bash
lake build
./.lake/build/bin/Main
```

---

**Technical Disclaimer:**
This project contains components developed with AI assistance.
- **Human-Authored**: The entire Lean 4 core (`PropLogicKernel/`, `REPL/`, `Main.lean`).
- **AI-Generated Wrappers**: All Python integration (`main.py`, `py_prop_logic_kernel/`, `examples/`), the TypeScript port (`ts_prop_logic_kernel/`), and this documentation.
