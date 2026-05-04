import PropLogicKernel.Basic
import PropLogicKernel.Printer
import PropLogicKernel.ListMap

namespace PropLogicKernel.Resolver

open PropLogicKernel.Basic
open PropLogicKernel.Printer
open PropLogicKernel.ListMap

-- resolveTacticToGoal?
-- apply tactic, return a new list of goals
-- and a new varCount variable
def resolveTacticToGoal? [Map α Nat P] (varCount: Nat) (g: G α) (t: T) (cl : Bool): Except String (Nat × List (G α)) :=
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

  match (g.goal, t, h?) with
    -- if goal is A → B
    -- add assumption h: A and change goal to B
    | (.imp A B, .intro, _) =>
      Except.ok (varCount + 1, [{
        hyp := Map.set g.hyp varCount A,
        goal := B,
      }])

    -- if goal is B and h: A → B
    -- change to to A
    | (B, .apply _, some (.imp A1 B1)) =>
      if B == B1 then
        Except.ok (varCount, [{
          hyp := g.hyp,
          goal := A1,
        }])
      else
        Except.error s!"cannot apply {h?} into {B}"

    -- if goal is A and h: A
    -- done
    | (A, .exact _, some A1) =>
      if A == A1 then
        Except.ok (varCount, [])
      else
        Except.error s!"cannot exact {h?} into {A}"

    -- if goal is A ∧ B
    -- split into two goals A and B
    | (.and A B, .constructor, _) =>
      Except.ok (varCount, [
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
      Except.ok (varCount, [{
        hyp := g.hyp,
        goal := A,
      }])
    -- if goal is A ∨ B
    -- change goal to B
    | (.or A B, .right, _) =>
      Except.ok (varCount, [{
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
      Except.ok (varCount + 2, [
        {
          hyp := (Map.set g.hyp varCount A),
          goal := g.goal,
        },
        {
          hyp := (Map.set g.hyp (varCount+1) B),
          goal := g.goal,
        },
      ])
    | (_, .cases _, some (.and A B)) =>
      Except.ok (varCount + 2, [{
        hyp := (Map.set (Map.set g.hyp varCount A) (varCount+1) B),
        goal := g.goal,
      }])
    | (_, .cases _, some (.fals)) =>
      Except.ok (varCount, [])

    -- CLASSICAL LOGIC

    -- law of excluded middle
    -- add ¬ A ∨ A
    | (_, .lem A, _) =>
      if cl then
        Except.ok (varCount + 1, [{
          hyp := (Map.set g.hyp varCount (P.or (.imp A .fals) A)),
          goal := g.goal,
        }])
      else
        Except.error s!"lem is only available in classical logic"

    -- if goal is B and h: A1 → B1
    -- split into two goals A1 and (B1 → B)
    | (B, .refine _, some (.imp A1 B1)) =>
      if cl then
        Except.ok (varCount, [{
          hyp := g.hyp,
          goal := (.imp B1 B),
        }, {
          hyp := g.hyp,
          goal := A1,
        }])
      else
        Except.error s!"refine is only available in classical logic"

    | _ => Except.error s!"cannot resolve tactic {t}"


def resolveTactic? [Map α Nat P] (s: S α) (t: T) (cl : Bool := False): Except String (S α) :=
  match t with
    -- new tactic acts on empty set of goals
    -- add a goal into the current state
    | .new C => Except.ok {
      varCount := s.varCount,
      sorrCount := s.sorrCount,
      newCount := s.newCount + 1,
      stack := {
        hyp := (Map.empty Nat P: α),
        goal := C,
      } :: s.stack,
    }

    -- sorry -- remove the current goal
    | .sorr =>
      match s.stack with
        | [] => Except.error s!"cannot resolve {t} into an empty set of goals"
        | _ :: remainingGoals =>
          Except.ok {
            varCount := s.varCount,
            sorrCount := s.sorrCount + 1,
            newCount := s.newCount,
            stack := remainingGoals,
          }

    -- other tactics acts on a goal and might return multiple goals
    | _ =>
      match s.stack with
        | [] => Except.error s!"cannot resolve {t} into an empty set of goals"
        | g :: remainingGoals =>
          match resolveTacticToGoal? s.varCount g t cl with
            | Except.error msg => Except.error msg
            | Except.ok (newVarCount, newGoals) => Except.ok {
              varCount := newVarCount,
              sorrCount := s.sorrCount,
              newCount := s.newCount,
              stack := newGoals ++ remainingGoals,
            }

end PropLogicKernel.Resolver
