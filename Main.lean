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

def printState (s: State): String :=
  match s.stack with
    | [] => "no_more_goal"
    | g :: _ => s!"current_goal (1 / {s.stack.length})\n{g}"

def apply (s: State) (line: String): State × String :=
  let t?: Option T := parseTactic? line.trimAscii.toString
  match t? with
    | none => (s, "parse error, try again")
    | some t =>
      match resolveTactic? s t with
        | Except.error msg => (s, msg)
        | Except.ok s =>
          let msg := s!"resolved tactic {t}\n\n{printState s}"
          (s, msg)

def main : IO Unit := do
  IO.println "Hello"
  let A := P.atom "A"
  let B := P.atom "B"
  let s := initState (emptyList: ListMap Nat P)
      (.imp (.and A B) (.and B A))
  EchoLine.main_loop apply s (printState s)
  IO.println "Goodbye!"
