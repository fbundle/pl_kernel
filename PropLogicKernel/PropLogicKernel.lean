
abbrev Name := String

-- proposition
inductive P where
  | false: P
  | atom (name: Name): P
  | not (this: P): P
  | and (this: P) (that: P): P
  | or (this: P) (that: P): P
  | imp (this: P) (that: P): P



abbrev Key := Nat

-- tactic
inductive T where
  -- if goal is P → Q
  -- add assumption h: P and change goal to Q
  | intro: T
  -- if goal is Q and h: P → Q
  -- change to to P
  | apply (h: Key): T
  -- if goal is P and h: P
  -- done
  | exact (h: Key): T
  -- if goal is P ∧ Q
  -- split into two goals P and Q
  | constructor: T
  -- if h: P ∨ Q
  -- split into two subproblems (assume h₁: P) and (assume h₂: Q)
  -- if h: P ∧ Q
  -- add (h₁: P) and (h₂: Q)
  -- if h: False
  -- done ex falso quodlibet (from False, anything follows)
  | cases (h: Key): T
  -- if goal is P ∨ Q
  -- change goal to P
  | left: T
  -- if goal is P ∨ Q
  -- change goal to Q
  | right: T

-- hash map
class Ctx (α: Type) where
  get (name: Key): Option P
  set (m: α) (name: Key) (prop: P): α
  size: Nat

-- hypothesis
structure H (α: Type) [Ctx α] where
  parent: Option (H α)
  terms: α


-- problem
structure G (α: Type) [Ctx α] where
  hypothesis: H α
  goal: P

abbrev  State α [Ctx α] := List (G α)

def applyTactic? {α} [Ctx α] (stack: State α) (t: T): Except String (State α) :=
  sorry
