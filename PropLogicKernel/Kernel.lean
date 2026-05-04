import PropLogicKernel.ListMap

namespace PropLogicKernel.Kernel

open PropLogicKernel.ListMap

/--
basic data structures
Prop
Goal  -- a proposition and hypotheses
State --  a list of goals to solve
Tactic -- a rule to change state
--/

-- proposition
inductive P where
  | fals: P
  | var (name: String): P
  | and (this: P) (that: P): P
  | or (this: P) (that: P): P
  | imp (this: P) (that: P): P
  deriving BEq

-- tactic
inductive T where
  -- if goal is A → B
  -- add hyp h: A and replace goal with B
  | intro: T
  -- if goal is A and h: A
  -- goal is accomplished
  | exact (n: Nat): T
  -- if goal is B and h: A → B
  -- replace goal with A
  | apply (n: Nat): T
  -- if goal is B and h: A1 → B1
  -- split into two goals A1 and (B1 → B)
  | bridge (n: Nat): T
  -- combine exact, apply, bridge
  | refine (n: Nat): T
  -- if goal is A ∧ B
  -- split into two goals A and B
  | constructor: T
  -- if goal is A ∨ B
  -- replace goal with A
  | left: T
  -- if goal is A ∨ B
  -- replace goal with B
  | right: T

  -- if h: A ∨ B
  -- branch intro (hyp h₁: A) and (hyp h₂: B)
  -- if h: A ∧ B
  -- add hyp (h₁: A) and (h₂: B)
  -- if h: False
  -- done ex falso quodlibet (from False, anything follows)
  -- cases doesn't resolve implication
  | cases (h: Nat): T

  -- CLASSICAL LOGIC
  -- law of excluded middle
  -- add hyp ¬ A ∨ A
  | lem (p: P): T

  -- APPLICATION LEVEL
  -- sorry - just sorry
  | sorr: T
  -- add a goal into the current state
  | new (p: P): T

-- goal
structure G (α: Type) [Map α Nat P] where
  hyp: α
  goal: P

partial def T.resolveGoal? [Map α Nat P] (t: T) (vc: Nat) (cl : Bool) (g: G α): Option (Nat × List (G α)) :=
  -- (h: Option Nat) => (h: Option P)
  let h?: Option P :=
    let n?: Option Nat :=
      match t with
        | .apply n => some n
        | .exact n => some n
        | .cases n => some n
        | .refine n => some n
        | _ => none
    match n? with
      | none => none
      | some n => Map.get? g.hyp n

  match (g.goal, t, h?) with
    -- if goal is A → B
    -- add hyp h: A and replace goal with B
    | (.imp A B, .intro, _) =>
      some (vc+1, [
        {g with hyp := Map.set g.hyp vc A, goal := B},
      ])

    -- if goal is A and h: A
    -- goal is accomplished
    | (A, .exact _, some A1) =>
      if A == A1 then
        some (vc, [])
      else
        none

    -- if goal is B and h: A → B
    -- replace goal with A
    | (B, .apply _, some (.imp A1 B1)) =>
      if B == B1 then
        some (vc, [
          {g with goal := A1},
        ])
      else
        none

    -- if goal is B and h: A1 → B1
    -- split into two goals A1 and (B1 → B)
    | (B, .bridge _, some (.imp A1 B1)) =>
      some (vc, [
        {g with goal := A1},
        {g with goal := .imp B1 B},
      ])

    -- combine exact, apply, bridge
    | (_, .refine n, _) =>
      T.resolveGoal? (.exact n) vc cl g
      <|>
      T.resolveGoal? (.apply n) vc cl g
      <|>
      T.resolveGoal? (.bridge n) vc cl g

    -- if goal is A ∧ B
    -- split into two goals A and B
    | (.and A B, .constructor, _) =>
      some (vc, [
        {g with goal := A},
        {g with goal := B},
      ])
    -- if goal is A ∨ B
    -- replace goal with A
    | (.or A B, .left, _) =>
      some (vc, [
        {g with goal := A},
      ])
    -- if goal is A ∨ B
    -- replace goal with B
    | (.or A B, .right, _) =>
      some (vc, [
        {g with goal := B},
      ])

    -- if h: A ∨ B
    -- branch intro (hyp h₁: A) and (hyp h₂: B)
    -- if h: A ∧ B
    -- add hyp (h₁: A) and (h₂: B)
    -- if h: False
    -- done ex falso quodlibet (from False, anything follows)
    -- cases doesn't resolve implication
    | (_, .cases _, some (.or A B)) =>
      some (vc + 2, [
        {g with hyp := Map.set g.hyp vc A},
        {g with hyp := Map.set g.hyp (vc+1) B},
      ])
    | (_, .cases _, some (.and A B)) =>
      some (vc + 2, [
        {g with hyp := Map.set (Map.set g.hyp vc A) (vc+1) B},
      ])
    | (_, .cases _, some (.fals)) =>
      some (vc, [])

    -- CLASSICAL LOGIC

    -- law of excluded middle
    -- add hyp ¬ A ∨ A
    | (_, .lem A, _) =>
      if ¬ cl then none else
      some (vc + 1, [
        {g with hyp := Map.set g.hyp vc (P.or (.imp A .fals) A)},
      ])

    | _ => none

-- state
structure S (α: Type) [Map α Nat P] where
  varCount: Nat
  sorrCount: Nat
  newCount: Nat
  stack: List (G α)

def T.resolveState? [Map α Nat P] (t: T) (cl: Bool) (s: S α): Option (S α) :=
  match (t, s.stack) with
    -- add a goal into the current state
    | (.new C, _) => some
      {s with
        newCount := s.newCount+1,
        stack := {hyp := (Map.empty Nat P: α), goal := C} :: s.stack,
      }

    -- sorry
    | (.sorr, _ :: gs) => some
      {s with
        sorrCount := s.sorrCount + 1,
        stack := gs,
      }

    -- other tactics act on goal at the top
    | (_, g :: gs) =>
      match t.resolveGoal? s.varCount cl g with
        | none => none
        | some (vc, ga) => some
          {s with
            varCount := vc,
            stack := ga ++ gs,
          }

    | _ => none










end PropLogicKernel.Kernel
