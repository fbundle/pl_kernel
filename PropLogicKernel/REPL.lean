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
      "tactics available: `intro` `exact` `apply` `compose` `constructor` `left` `right` `cases` `lem`"
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
        let ts := Auto.getAllAvailTactics g (checkAhead := true)
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


def handleEmpty? (state: State) (inputLine: String): Option (REPL.Step State) :=
  if inputLine.length == 0 then
    getStep state
  else
    none

def handleAuto? (state: State) (inputLine: String) : Option (REPL.Step State) :=
  match Parser.parsePrefixAndThen "auto " String.toNat? inputLine with
    | some depth =>
      match Auto.autoSolveWithMaxDepth? depth state with
        | some (newS, path) => getStep state s!"solved: {toStringTs path.reverse}"
        | none => getStep state s!"unsolvable with depth {depth}"
    | _ => none

def handleNew? (state: State) (inputLine: String) : Option (REPL.Step State) :=
  match Parser.parsePrefixAndThen "new " Parser.parseProp? inputLine with
    | some p =>
    getStep {state with
      newCount := state.newCount + 1,
      stack := {hyp := Ctx.empty , goal := p} :: state.stack,
    }
    | _ => none

def handleSorry? (state: State) (inputLine: String) : Option (REPL.Step State) :=
  if inputLine == "sorry" then
    getStep {state with
      sorrCount := state.sorrCount + 1,
      stack := state.stack.drop 1,
    }
  else
    none

def handleTactic? (state: State) (inputLine: String) (cl: Bool := true) : REPL.Step State :=
  match Parser.parseTactic? inputLine with
    | none => getStep state "parse error"
    | some tactic =>
        match tactic.resolveState? cl state with
          | none => getStep state "resolve error"
          | some newState => getStep newState



def trans (state: State) (inputLine: String): REPL.Step State :=
  let inputLine := inputLine.trimAscii.toString

  let newState? :=
  handleEmpty? state inputLine
  <|>
  handleAuto? state inputLine
  <|>
  handleNew? state inputLine
  <|>
  handleSorry? state inputLine

  match newState? with
    | some newState => newState
    | none => handleTactic? state inputLine



end PropLogicKernel.REPL
