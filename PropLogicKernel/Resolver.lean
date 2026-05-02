import PropLogicKernel.Basic
import PropLogicKernel.Printer
import PropLogicKernel.ListMap

namespace PropLogicKernel.Resolver

open PropLogicKernel.Basic
open PropLogicKernel.Printer
open PropLogicKernel.ListMap

-- resolveTacticToGoal?
-- apply tactic, return a new list of goals
-- and a new count variable
def resolveTacticToGoal? [Map α Nat P] (count: Nat) (g: G α) (t: T) (classical : Bool): Except String (Nat × List (G α)) :=
  -- get h? if specified
  let h?: Option P :=
    let hName?: Option Nat :=
      match t with
        | .apply hName => some hName
        | .exact hName => some hName
        | .cases hName => some hName
        | .refine hName => some hName
        | _ => none
    match hName? with
      | none => none
      | some hName => Map.get? g.hyp hName

  dbg_trace s!"----- {g.goal} {t} {h?}"
  match (g.goal, t, h?) with
    -- if goal is A → B
    -- add assumption h: A and change goal to B
    | (.imp A B, .intro, _) =>
      Except.ok (count + 1, [{
        hyp := Map.set g.hyp count A,
        goal := B,
      }])

    -- if goal is B and h: A → B
    -- change to to A
    | (B, .apply _, some (.imp A1 B1)) =>
      if B == B1 then
        Except.ok (count, [{
          hyp := g.hyp,
          goal := A1,
        }])
      else
        Except.error s!"cannot apply {h?} into {B}"

    -- if goal is A and h: A
    -- done
    | (A, .exact _, some A1) =>
      if A == A1 then
        Except.ok (count, [])
      else
        Except.error s!"cannot exact {h?} into {A}"

    -- if goal is A ∧ B
    -- split into two goals A and B
    | (.and A B, .constructor, _) =>
      Except.ok (count, [
        {
          hyp := g.hyp,
          goal := A,
        },
        {
          hyp := g.hyp,
          goal := B,
        }
      ])

    -- if goal is A ∨ B
    -- change goal to A
    | (.or A B, .left, _) =>
      Except.ok (count, [{
        hyp := g.hyp,
        goal := A,
      }])
    -- if goal is A ∨ B
    -- change goal to B
    | (.or A B, .right, _) =>
      Except.ok (count, [{
        hyp := g.hyp,
        goal := B,
      }])

    -- if h: A ∨ B
    -- split into two subproblems (assume h₁: A) and (assume h₂: B)
    -- if h: A ∧ B
    -- add (h₁: A) and (h₂: B)
    -- if h: False
    -- done ex falso quodlibet (from False, anything follows)
    -- cases doesn't resolve implication
    | (_, .cases _, some (.or A B)) =>
      Except.ok (count + 2, [
        {
          hyp := (Map.set g.hyp count A),
          goal := g.goal,
        },
        {
          hyp := (Map.set g.hyp (count+1) B),
          goal := g.goal,
        },
      ])
    | (_, .cases _, some (.and A B)) =>
      Except.ok (count + 2, [{
        hyp := (Map.set (Map.set g.hyp count A) (count+1) B),
        goal := g.goal,
      }])
    | (_, .cases _, some (.fals)) =>
      Except.ok (count, [])

    -- CLASSICAL LOGIC

    -- law of excluded middle
    -- add (A → False) ∨ A
    | (_, .lem A, _) =>
      if classical then
        Except.ok (count + 1, [{
          hyp := (Map.set g.hyp count (P.or (.imp A .fals) A)),
          goal := g.goal,
        }])
      else
        Except.error s!"lem is only available in classical logic"

    -- if goal is B and h: A1 → B1
    -- split into two goals A1 and (B1 → B)
    | (B, .refine _, some (.imp A1 B1)) =>
      if classical then
        Except.ok (count, [{
          hyp := g.hyp,
          goal := A1,
        }, {
          hyp := g.hyp,
          goal := (.imp B1 B),
        }])
      else
        Except.error s!"refine is only available in classical logic"

    -- APPLICATION LEVEL

    -- sorry
    | (_, .sorr, _) =>
      Except.ok (count, [])

    -- add a goal into the current state
    | (_, .new C, _) =>
      Except.ok (count, [g, {
        hyp := (Map.empty Nat P: α),
        goal := C,
      }])

    | _ => Except.error s!"cannot resolve tactic {t}"

def resolveTactic? [Map α Nat P] (s: S α) (t: T) (classical : Bool := False): Except String (S α) :=
  match s.stack with
    | [] => Except.error "empty list of goals"
    | g :: remainingGoals =>
      match resolveTacticToGoal? s.count g t classical with
        | Except.error msg => Except.error msg
        | Except.ok (newCount, newGoals) => Except.ok {
          count := newCount,
          stack := newGoals ++ remainingGoals,
        }

end PropLogicKernel.Resolver
