import PropLogicKernel.Kernel
import PropLogicKernel.Parser
import PropLogicKernel.Printer
import PropLogicKernel.ListMap
import PropLogicKernel.Auto


import REPL.REPL

namespace PropLogicKernel.REPL

open PropLogicKernel
open PropLogicKernel.ListMap

abbrev State := S (ListMap Nat P)


def toStringTs (ts: List T): String :=
  let ts := ts.map (λ t => s!"{t}")
  let ts := String.intercalate "][" ts
  s!"[{ts}]"

def getStep (s: State) (message?: Option String := none) (hint: Bool := true): REPL.Step State :=
  let isAllGoalsAccomplished (s: State): Bool :=
    s.stack.isEmpty ∧ (s.sorrCount == 0) ∧ (s.newCount ≥ 1)

  let getCode (s: State): UInt32 :=
    if isAllGoalsAccomplished s then 0 else 1

  let out: List String :=
    match s.stack with
      | [] => []
      | g :: _ =>
        (Printer.toLinesGoal g).reverse

  let status: List String := []

  let status: List String := if s.newCount == 0 then
    status ++ [
      "type `new <prop>` input a new goal and `auto <max_depth>` for search",
      "tactics available: `intro` `exact` `apply` `compose` `constructor` `left` `right` `cases` `lem` `refine` `sorry` `new`"
    ]
  else
    status
  let status: List String :=
    status ++ [s!"new_count {s.newCount} sorry_count {s.sorrCount} var_count {s.varCount} goals_remaining {s.stack.length}"]

  let status: List String :=
    if isAllGoalsAccomplished s then
      status ++ ["all goals accomplished!"]
    else if hint then
      match s.stack with
      | [] => status
      | g :: _ =>
        let ts := Auto.getAllAvailTactics g (checkAhead := True)
        status ++ [s!"hint: {toStringTs ts}"]
    else
      status

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


def trans (state: State) (inputLine: String) (cl: Bool := true): REPL.Step State :=
  let inputLine := inputLine.trimAscii.toString

  if inputLine.length == 0 then
    getStep state
  else
    match Parser.parsePrefixAndThen "auto " String.toNat? inputLine with
      | some depth =>
        match Auto.autoSolveWithMaxDepth? depth state with
          | some path =>
            getStep state s!"solved: {toStringTs path.reverse}"
          | none => getStep state s!"unsolvable with depth {depth}"
      | _ =>
        match Parser.parseTactic? inputLine with
          | none => getStep state "parse error"
          | some tactic =>
              match tactic.resolveState? cl state with
                | none => getStep state "resolve error"
                | some newState => getStep newState


end PropLogicKernel.REPL
