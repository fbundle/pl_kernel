import PropLogicKernel.ListMap


-- proposition
inductive P where
  | fals: P
  | atom (name: String): P
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
  -- if h: A ∨ B
  -- split into two subproblems (assume h₁: A) and (assume h₂: B)
  -- if h: A ∧ B
  -- add (h₁: A) and (h₂: B)
  -- if h: False
  -- done ex falso quodlibet (from False, anything follows)
  -- cases doesn't resolve implication
  | cases (h: Nat): T
  -- if goal is A ∨ B
  -- change goal to A
  | left: T
  -- if goal is A ∨ B
  -- change goal to B
  | right: T

-- goal
structure G (α: Type) [Map α Nat P] where
  hyp: α
  goal: P

-- state - a list of goals to solve
structure S (α: Type) [Map α Nat P] where
  count: Nat
  stack: List (G α)

def initState [Map α Nat P] (emptyList: α) (p: P) : S α :=
  {count := 0, stack := [{hyp := emptyList, goal := p}]}



def hello := "world"
