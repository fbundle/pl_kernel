import EchoLine.EchoLine
import PropLogicKernel.Basic
import PropLogicKernel.ListMap
import PropLogicKernel.Resolver
import PropLogicKernel.Parser

open PropLogicKernel.Basic
open PropLogicKernel.ListMap
open PropLogicKernel.Parser
open PropLogicKernel.Resolver

abbrev State := S (ListMap Nat P)

def prompt (s: State): String :=
  match s.stack with
    | [] => "\nno_more_goal\n> "
    | g :: _ => s!"\ncurrent_goal (1 / {s.stack.length})\n{g}\n> "

def s0: State := {
  count := 0,
  stack := [],
}

def classical: Bool := True

-- A ∧ B → B ∧ A
-- (.imp (.and A B) (.and B A))
-- (A → B) ∧ (B → ⊥) → A → ⊥
-- (.imp (.and (.imp A B) (.imp B .fals)) (.imp A .fals))
-- A → (A → B) → (A → C) → (B ∨ C → D) → D
-- (impMany [A, (.imp A B), (.imp A C), (.imp (.or B C) D)] D)

-- ((P → ⊥) → ⊥) → P -- need classical logic
def p0: String := "type `new <goal>` to add new goal\n> "

def stateTransition (state: State) (inputLine: String): (State × String) :=
  match parseTactic? inputLine with
    | none => (state, "parse error, try again\n> ")
    | some t =>
      match resolveTactic? state t classical with
        | Except.error msg => (state, msg ++ "\n> ")
        | Except.ok newState => (newState, prompt newState)

def main : IO UInt32 := do
  EchoLine.loop stateTransition s0 p0
  return 0
