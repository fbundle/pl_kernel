
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



inductive T where
  -- if goal is P → Q
  -- add assumption h: P and change goal to Q
  | intro: T
  -- if goal is Q and h: P → Q
  -- change to to P
  | apply (h: String): T
  -- if goal is P and h: P
  -- done
  | exact (h: String): T
  -- if goal is P ∧ Q
  -- split into two goals P and Q
  | constructor: T
  -- if h: P ∨ Q
  -- split into two subproblems (assume h₁: P) and (assume h₂: Q)
  -- if h: P ∧ Q
  -- add (h₁: P) and (h₂: Q)
  -- if h: False
  -- done ex falso quodlibet (from False, anything follows)
  | cases (h: String): T
  -- if goal is P ∨ Q
  -- change goal to P
  | left: T
  -- if goal is P ∨ Q
  -- change goal to Q
  | right: T
