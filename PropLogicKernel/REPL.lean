import PropLogicKernel.Kernel
import PropLogicKernel.Parser
import PropLogicKernel.Printer

import REPL.REPL

namespace PropLogicKernel.REPL

open PropLogicKernel

def ListMap α β [BEq α] := List (α × β)

def get? [BEq α] (map: ListMap α β) (key: α): Option β :=
  match map with
    | [] => none
    | (k, v) :: xs =>
      if k == key then
        some v
      else
        get? xs key

def set [BEq α] (map: ListMap α β) (key: α) (val: β): ListMap α β :=
  (key, val) :: map

def iter [BEq α] (map: ListMap α β) := map

def empty [BEq α]: ListMap α β := []

instance[BEq α]: Map (ListMap α β) α β  where
  empty := empty
  get? := get?
  set := set
  iter := iter

abbrev State := S (ListMap Nat P)

def getStep (s: State) (message?: Option String := none): REPL.Step State :=
  let isAllGoalsAccomplished (s: State): Bool :=
    s.stack.isEmpty ∧ (s.sorrCount == 0) ∧ (s.newCount ≥ 1)

  let getCode (s: State): UInt32 :=
    if isAllGoalsAccomplished s then 0 else 1

  let out: List String :=
    match s.stack with
      | [] => []
      | g :: _ =>
        let (goal, hyp) := Printer.toLinesGoal g
        (goal :: hyp).reverse

  let status: List String :=
    [s!"new_count {s.newCount} sorry_count {s.sorrCount} var_count {s.varCount} goals_remaining {s.stack.length}"]

  let status: List String :=
    if ¬ isAllGoalsAccomplished s then status else
      status ++ ["all goals accomplished!"]

  let status: List String :=
    match message? with
      | none => status
      | some message => message :: status

  {
    state := s,
    code := getCode s,
    err := status,
    out := out,
  }

def init: REPL.Step State :=
  getStep {
    varCount := 0,
    sorrCount := 0,
    newCount := 0,
    stack := []
  }

def trans (classical_logic: Bool) (state: State) (inputLine: String): REPL.Step State :=
  let inputLine := inputLine.trimAscii.toString

  if inputLine.length == 0 then
    getStep state
  else
    match Parser.parseTactic? inputLine with
      | none => getStep state "parse error"
      | some tactic =>
          match tactic.resolveState? classical_logic state with
            | none => getStep state "resolve error"
            | some newState => getStep newState


end PropLogicKernel.REPL
