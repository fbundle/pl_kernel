
-- proposition
inductive P where
  | false: P
  | not (this: P): P
  | and (this: P) (that: P): P
  | or (this: P) (that: P): P
  | imp (this: P) (that: P): P

def toString (p: P): String :=
  match p with
    | .false => "False"
    | .not this => s!"¬ {toString this}"
    | .and this that => s!"({toString this} ∧ {toString that})"
    | .or this that => s!"({toString this} ∨ {toString that})"
    | .imp this that => s!"({toString this} → {toString that})"


abbrev Name := Nat

-- tactic
inductive T where
  -- if goal is P → Q
  -- add assumption h: P and change goal to Q
  | intro: T
  -- if goal is Q and h: P → Q
  -- change to to P
  | apply (h: Name): T
  -- if goal is P and h: P
  -- done
  | exact (h: Name): T
  -- if goal is P ∧ Q
  -- split into two goals P and Q
  | constructor: T
  -- if h: P ∨ Q
  -- split into two subproblems (assume h₁: P) and (assume h₂: Q)
  -- if h: P ∧ Q
  -- add (h₁: P) and (h₂: Q)
  -- if h: False
  -- done ex falso quodlibet (from False, anything follows)
  | cases (h: Name): T
  -- if goal is P ∨ Q
  -- change goal to P
  | left: T
  -- if goal is P ∨ Q
  -- change goal to Q
  | right: T

-- hash map
class Ctx (α: Type) where
  get (name: Name): Option P
  set (m: α) (name: Name) (prop: P): α
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

def apply_tactic {α} [Ctx α] (stack: State α) (t: T): State α :=
  sorry
