import EchoLine.EchoLine
import PropLogicKernel.Resolve

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

def stateTransition (state: State) (inputLine: String): (State × String × Bool) :=
  let t?: Option T := parseTactic? inputLine.trimAscii.toString
  match t? with
    | none => (state, "parse error, try again", true)
    | some t =>
      match resolveTactic? state t with
        | Except.error msg => (state, msg, true)
        | Except.ok newState => (newState, prompt newState, true)

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
  EchoLine.loop stateTransition s (prompt s) true
  IO.println "Goodbye!"
  return 0
