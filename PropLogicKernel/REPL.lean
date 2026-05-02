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

def isAllGoalsAccomplished (s: State): Bool :=
  s.stack.isEmpty ∧ (s.sorrCount == 0) ∧ (s.newCount ≥ 1)

def getCode (s: State): UInt32 :=
  if isAllGoalsAccomplished s then
    0
  else
    1



def getPrompt (s: State): REPL.Step State :=
  match s.stack with
    | [] =>
      let allGoalsAccomplished: List String :=
        if isAllGoalsAccomplished s then
          ["all goals accomplished!"]
        else
          []
      {
        state := s,
        code := getCode s,
        err := [
          s!"new_count {s.newCount} sorry_count {s.sorrCount} var_count {s.varCount} goals_remaining {s.stack.length}",
        ] ++ allGoalsAccomplished,
        out := [],
      }
    | g :: _ =>
      let (goal, hyp) := toLinesGoal g
      let lines := (goal :: hyp).reverse
      {
        state := s,
        code := getCode s,
        err := [
          s!"new_count {s.newCount} sorry_count {s.sorrCount} var_count {s.varCount} goals_remaining {s.stack.length}",
        ],
        out := lines,
      }
def init: REPL.Step State :=
  getPrompt {
    varCount := 0,
    sorrCount := 0,
    newCount := 0,
    stack := []
  }
def trans (classical_logic: Bool) (s: State) (inputLine: String): REPL.Step State :=
  let inputLine := inputLine.trimAscii.toString

  if inputLine.length == 0 then
    {
        state := s,
        code := getCode s,
        err := [],
        out := [],
    }
  else
    match parseTactic? inputLine with
      | none =>
        {
          state := s,
          code := getCode s,
          err := ["parse error"],
          out := [],
        }
      | some tactic =>
        match resolveTactic? s tactic classical_logic with
          | Except.error msg =>
            {
              state := s,
              code := getCode s,
              err := [msg],
              out := [],
            }
          | Except.ok newS => getPrompt newS

end PropLogicKernel.REPL
