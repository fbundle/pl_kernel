import PropLogicKernel.Basic
import PropLogicKernel.ListMap
import PropLogicKernel.Parser
import PropLogicKernel.Resolver
import PropLogicKernel.Printer

import REPL.REPL

namespace PropLogicKernel.REPL

open PropLogicKernel.Basic
open PropLogicKernel.ListMap
open PropLogicKernel.Parser
open PropLogicKernel.Resolver
open PropLogicKernel.Printer

abbrev State := S (ListMap Nat P)

def init: REPL.Step State :=
  {
    state := {count := 0, stack := []},
    err := ["type `new <goal>` to add new goal"],
    out := [],
  }
def getPrompt (s: State): REPL.Step State :=
  match s.stack with
    | [] =>
      {
        state := s,
        err := ["all goals accomplished!"],
        out := [],
      }
    | g :: _ =>
      let (goal, hyp) := toLinesGoal g
      let lines := (goal :: hyp).reverse
      {
        state := s,
        err := [s!"goals remaining {s.stack.length}"],
        out := lines,
      }

def trans (classical_logic: Bool) (state: State) (inputLine: String): REPL.Step State :=
  let inputLine := inputLine.trimAscii.toString

  if inputLine.length == 0 then
    {
        state := state,
        err := [],
        out := [],
    }
  else
    match parseTactic? inputLine with
      | none =>
        {
          state := state,
          err := ["parse error"],
          out := [],
        }
      | some tactic =>
        match resolveTactic? state tactic classical_logic with
          | Except.error msg =>
            {
              state := state,
              err := [msg],
              out := [],
            }
          | Except.ok newState => getPrompt newState

end PropLogicKernel.REPL
