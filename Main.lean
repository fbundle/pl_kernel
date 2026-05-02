import EchoLine.EchoLine
import PropLogicKernel.REPL


def classical_logic: Bool := True

-- A ∧ B → B ∧ A
-- (A → B) ∧ (B → ⊥) → A → ⊥
-- A → (A → B) → (A → C) → (B ∨ C → D) → D
-- ((P → ⊥) → ⊥) → P -- need classical logic

def main : IO UInt32 := do
  let (state, prompt) := PropLogicKernel.REPL.init
  let repl := PropLogicKernel.REPL.REPL classical_logic

  EchoLine.loop repl state prompt
  return 0
