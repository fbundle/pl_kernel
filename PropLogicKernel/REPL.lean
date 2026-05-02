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

structure AppState where
  state: State
  sorryCount: Nat
  newCount: Nat

def getCode (s: AppState): UInt32 :=
  if s.state.stack.isEmpty ∧ (s.sorryCount == 0) ∧ (s.newCount ≥ 1) then
    0
  else
    1

def init: REPL.Step AppState :=
  let s := {
    state := {count := 0, stack := []},
    sorryCount := 0,
    newCount := 0,
  }
  {
    state := s,
    code := getCode s,
    err := ["type `new <goal>` to add new goal"],
    out := [],
  }

def getPrompt (s: AppState): REPL.Step AppState :=
  match s.state.stack with
    | [] =>
      {
        state := s,
        code := getCode s,
        err := ["all goals accomplished!"],
        out := [],
      }
    | g :: _ =>
      let (goal, hyp) := toLinesGoal g
      let lines := (goal :: hyp).reverse
      {
        state := s,
        code := getCode s,
        err := [s!"goals remaining {s.state.stack.length}"],
        out := lines,
      }

def trans (classical_logic: Bool) (s: AppState) (inputLine: String): REPL.Step AppState :=
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
        let newSorryCount := s.sorryCount + match tactic with
          | .sorr => 1
          | _ => 0
        let newNewCount := s.newCount + match tactic with
          | .new _ => 1
          | _ => 0

        match resolveTactic? s.state tactic classical_logic with
          | Except.error msg =>
            {
              state := s,
              code := getCode s,
              err := [msg],
              out := [],
            }
          | Except.ok newS => getPrompt {
            state := newS,
            sorryCount:= newSorryCount,
            newCount := newNewCount,
          }

end PropLogicKernel.REPL
