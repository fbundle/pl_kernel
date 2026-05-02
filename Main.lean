import EchoLine.EchoLine
import PropLogicKernel.Resolve
import PropLogicKernel.Parse

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
    else
      none

abbrev Goal := G (ListMap Nat P)

def parseInputLine? (inputLine: String): Option (T ⊕ Goal) := do
  if inputLine.startsWith "new " then
    let (p, _) := ← parseProp? (inputLine.drop 6).toString
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

-- def p0: String := "type `new <goal>` to add new goal\n> "
def p0: String := prompt s0

def stateTransition (state: State) (inputLine: String): (State × String) :=
  match parseInputLine? inputLine.trimAscii.toString with
    | none => (state, "parse error, try again\n> ")
    | some (Sum.inr g) =>
      ({count := state.count, stack := g :: state.stack}, "new goal added")

    | some (Sum.inl t) =>
      match resolveTactic? state t with
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
  IO.println "Hello"
  let A := P.atom "A"
  let B := P.atom "B"
  let C := P.atom "C"
  let D := P.atom "D"
  let s: State := initState (emptyList: ListMap Nat P)
      -- (.imp (.and A B) (.and B A))
      -- (.imp (.and (.imp A B) (.imp B .fals)) (.imp A .fals))
      (impMany [A, (.imp A B), (.imp A C), (.imp (.or B C) D)] D)
  EchoLine.loop stateTransition s (prompt s)
  IO.println "Goodbye!"
  return 0
