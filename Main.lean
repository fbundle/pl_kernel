import REPL.REPL
import PropLogicKernel.REPL


def classical_logic: Bool := True

-- A ∧ B → B ∧ A
-- (A → B) ∧ (B → ⊥) → A → ⊥
-- A → (A → B) → (A → C) → (B ∨ C → D) → D
-- ((P → ⊥) → ⊥) → P -- need classical logic

def main : IO UInt32 := do
  let init := PropLogicKernel.REPL.init
  let repl := PropLogicKernel.REPL.trans classical_logic

  REPL.run repl init
  return 0
