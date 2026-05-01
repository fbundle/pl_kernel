import EchoLine.EchoLine
import PropLogicKernel.Resolve

def parseTactic? (s: String): Option T :=
  match s.trimAscii.toString with
  | "intro" => some T.intro
  | "constructor" => some T.constructor
  | "left" => some T.left
  | "right" => some T.right
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

def isDone (s: State): Bool := s.stack.length == 0

def prompt (s: State): String :=
  match s.stack with
    | [] => "\nno_more_goal"
    | g :: _ => s!"\ncurrent_goal (1 / {s.stack.length})\n{g}\n> "

def apply (s: State) (line: String): Option (State × String) :=
  if isDone s then none else

  let t?: Option T := parseTactic? line.trimAscii.toString
  match t? with
    | none => (s, "parse error, try again")
    | some t =>
      match resolveTactic? s t with
        | Except.error msg => (s, msg)
        | Except.ok s =>
          (s, s!"resolved tactic {t}")


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


def main : IO Unit := do
  IO.println "Hello"
  let A := P.atom "A"
  let B := P.atom "B"
  let C := P.atom "C"
  let D := P.atom "D"
  let s := initState (emptyList: ListMap Nat P)
      -- (.imp (.and A B) (.and B A))
      -- (.imp (.and (.imp A B) (.imp B .fals)) (.imp A .fals))
      -- (impMany [A, (.imp A B), (.imp A C), (.imp (.or B C) D)] D)
  EchoLine.main_loop apply s prompt
  IO.println "Goodbye!"
