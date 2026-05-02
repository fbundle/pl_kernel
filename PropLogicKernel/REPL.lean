import PropLogicKernel.Basic
import PropLogicKernel.ListMap
import PropLogicKernel.Parser
import PropLogicKernel.Resolver

namespace PropLogicKernel.REPL

open PropLogicKernel.Basic
open PropLogicKernel.ListMap
open PropLogicKernel.Parser
open PropLogicKernel.Resolver

abbrev State := S (ListMap Nat P)

def init: (State × String) := (
  {count := 0, stack := []}, "type `new <goal>` to add new goal\n> "
)

def REPL (classical_logic: Bool) (state: State) (inputLine: String): (State × String) :=
  let prompt (s: State): String :=
    match s.stack with
      | [] => "all goals accomplished!\n> "
      | g :: _ => s!"current goals {s.stack.length}\n{g}\n> "

  let inputLine := inputLine.trimAscii.toString

  if inputLine.length == 0 then
    (state, "> ")
  else
    match parseTactic? inputLine with
      | none => (state, "parser error\n> ")
      | some tactic =>
        match resolveTactic? state tactic classical_logic with
          | Except.error msg => (state, msg)
          | Except.ok newState => (newState, prompt newState)

end PropLogicKernel.REPL
