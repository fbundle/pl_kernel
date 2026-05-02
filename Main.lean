import EchoLine.EchoLine
import PropLogicKernel.Basic
import PropLogicKernel.ListMap
import PropLogicKernel.Resolve
import PropLogicKernel.Parser

open PropLogicKernel.Basic
open PropLogicKernel.ListMap
open PropLogicKernel.Parser
open PropLogicKernel.Resolve

def parseTactic? (s: String): Option T :=
  match s.trimAscii.toString with
  | "intro" => some T.intro
  | "constructor" => some T.constructor
  | "left" => some T.left
  | "right" => some T.right
  | "sorry" => some T.sorr
  | _ =>
    if s.startsWith "apply " then
      (s.drop 6).toString |> String.toNat? |>.map T.apply
    else if s.startsWith "exact " then
      (s.drop 6).toString |> String.toNat? |>.map T.exact
    else if s.startsWith "cases " then
      (s.drop 6).toString |> String.toNat? |>.map T.cases
    else if s.startsWith "lem " then
      parseProp? ((s.drop 4).toString) |>.map (λ (p, _) => T.lem p)
    else
      none

abbrev Goal := G (ListMap Nat P)

def parseInputLine? (inputLine: String): Option (T ⊕ Goal) := do
  if inputLine.startsWith "new " then
    let (p, _) := ← parseProp? (inputLine.drop 4).toString
    pure (Sum.inr {hyp := emptyList, goal := p})
  else
    let t := ← parseTactic? inputLine
    pure (Sum.inl t)

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
-- def p0: String := prompt s0

def stateTransition (state: State) (inputLine: String): (State × String) :=
  match parseInputLine? inputLine.trimAscii.toString with
    | none => (state, "parse error, try again\n> ")
    | some (Sum.inr g) =>
      let newState: State := {
        count := state.count,
        stack := g :: state.stack,
      }
      (newState, "new goal added\n" ++ (prompt newState))

    | some (Sum.inl t) =>
      match resolveTactic? state t classical with
        | Except.error msg => (state, msg ++ "\n> ")
        | Except.ok newState => (newState, prompt newState)

def andMany (ps: List P) (last: P): P :=
  match ps with
    | [] => last
    | p :: [] => (.and p last)
    | p :: ps => (.and p (andMany ps last))

def impMany (ps: List P) (last: P): P :=
  match ps with
    | [] => last
    | p :: [] => (.imp p last)
    | p :: ps => (.imp p (impMany ps last))


def main : IO UInt32 := do
  EchoLine.loop stateTransition s0 p0
  return 0
