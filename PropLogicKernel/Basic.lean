import PropLogicKernel.ListMap

namespace PropLogicKernel.Basic

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
  -- add assumption h: A and change goal to B
  | intro: T
  -- if goal is B and h: A → B
  -- change to to A
  | apply (h: Nat): T
  -- if goal is A and h: A
  -- done
  | exact (h: Nat): T
  -- if goal is A ∧ B
  -- split into two goals A and B
  | constructor: T
  -- if goal is A ∨ B
  -- change goal to A
  | left: T
  -- if goal is A ∨ B
  -- change goal to B
  | right: T

  -- if h: A ∨ B
  -- split into two subproblems (assume h₁: A) and (assume h₂: B)
  -- if h: A ∧ B
  -- add (h₁: A) and (h₂: B)
  -- if h: False
  -- done ex falso quodlibet (from False, anything follows)
  -- cases doesn't resolve implication
  | cases (h: Nat): T

  -- CLASSICAL LOGIC
  -- law of excluded middle
  -- add (A → False) ∨ A
  | lem (p: P): T
  -- if goal is B and h: A1 → B1
  -- split into two goals A1 and (B1 → B)
  | refine (h: Nat): T

  -- APPLICATION LEVEL
  -- sorry - just sorry
  | sorr: T
  -- add a goal into the current state
  | new (p: P): T


-- goal
structure G (α: Type) [Map α Nat P] where
  hyp: α
  goal: P

-- state
structure S (α: Type) [Map α Nat P] where
  varCount: Nat
  sorrCount: Nat
  newCount: Nat
  stack: List (G α)

end PropLogicKernel.Basic
