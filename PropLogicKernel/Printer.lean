import PropLogicKernel.Basic

namespace PropLogicKernel.Printer

open PropLogicKernel.Basic
open PropLogicKernel.ListMap

/--
def toStringProp (p: P): String :=
  match p with
    | .fals => "⊥"
    | .atom name => name
    | .and this that => s!"({toStringProp this} ∧ {toStringProp that})"
    | .or this that => s!"({toStringProp this} ∨ {toStringProp that})"
    | .imp this that => s!"({toStringProp this} → {toStringProp that})"

--/

def toStringProp (p: P) (parent: Option P := none) (strict: Bool := False): String :=
  let precedence (p: Option P): Nat :=
    match p with
      | none => 999
      | some p =>
        match p with
          | .fals => 0
          | .atom _ => 0
          | .and _ _ => 1
          | .or _ _ => 2
          | .imp _ _ => 3

  let thisPrec := precedence p
  let parentPrec := precedence parent


  -- right precedence - we prefer to remove parens on the right
  -- A ∧ B ∧ C = A ∧ (B ∧ C)
  -- A ∨ B ∨ C = A ∨ (B ∨ C)
  -- A → B → C = A → (B → C)

  let addOptionalParens (s: String): String :=
    if strict ∧ thisPrec ≥ parentPrec then s!"({s})" else
    if (¬ strict) ∧ thisPrec > parentPrec then s!"({s})" else
    s

  match p with
    | .fals => "⊥"
    | .atom name => name
    | .and this that => addOptionalParens s!"{toStringProp this p true} ∧ {toStringProp that p false}"
    | .or this that => addOptionalParens s!"{toStringProp this p true} ∨ {toStringProp that p false}"
    | .imp this that => addOptionalParens s!"{toStringProp this p true} → {toStringProp that p false}"


instance: ToString P where
  toString := toStringProp

#eval (P.imp (P.or (P.and (P.atom "P") (P.atom "Q")) (P.atom "R")) (P.and (P.atom "P") (P.or (P.atom "Q") (P.atom "R"))))
#eval toStringProp (P.imp (P.or (P.and (P.atom "P") (P.atom "Q")) (P.atom "R")) (P.and (P.atom "P") (P.or (P.atom "Q") (P.atom "R"))))

def toStringTactic (t: T): String :=
  match t with
    | .intro => "intro"
    | .apply h => s!"apply {h}"
    | .exact h => s!"exact {h}"
    | .constructor => "constructor"
    | .left => "left"
    | .right => "right"
    | .cases h => s!"cases {h}"
    | .lem p => s!"lem {p}"
    | .refine h => s!"refine {h}"
    | .sorr => "sorry"
    | .new p => s!"new {p}"

instance: ToString T where
  toString := toStringTactic

def toLinesGoal [Map α Nat P] (g: G α): String × List String :=
  let hyp := (Map.iter g.hyp).map ((λ ((n, p): Nat × P) =>
    s!"{n}: {p}"
  ): (Nat × P) → String)
  let goal := s!"⊢ {g.goal}"
  (goal, hyp)

def toStringGoal [Map α Nat P] (g: G α): String :=
  let (goal, hyp) := toLinesGoal g
  let lines := (goal :: hyp).reverse
  String.intercalate "\n" lines

instance [Map α Nat P]: ToString (G α)  where
  toString := toStringGoal

end PropLogicKernel.Printer
