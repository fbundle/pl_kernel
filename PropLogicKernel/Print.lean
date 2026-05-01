import PropLogicKernel.Basic

def toStringProp (p: P): String :=
  match p with
    | .false => "False"
    | .atom name => name
    | .not this => s!"¬ {toStringProp this}"
    | .and this that => s!"({toStringProp this} ∧ {toStringProp that})"
    | .or this that => s!"({toStringProp this} ∨ {toStringProp that})"
    | .imp this that => s!"({toStringProp this} → {toStringProp that})"

instance: ToString P where
  toString := toStringProp

def printProp (p: P) (parent: Option P := none): String :=
  let precedence (p: Option P): Nat :=
    match p with
      | none => 999
      | some p =>
        match p with
          | .false => 0
          | .atom _ => 0
          | .not _ => 0
          | .and _ _ => 1
          | .or _ _ => 2
          | .imp _ _ => 3

  let thisPrec := precedence p
  let parentPrec := precedence parent

  let addOptionalParens (s: String): String :=
    if thisPrec ≥ parentPrec then s!"({s})" else s

  match p with
    | .false => "False"
    | .atom name => name
    | .not this => s!"¬ {printProp this p}"
    | .and this that => addOptionalParens s!"{printProp this p} ∧ {printProp that p}"
    | .or this that => addOptionalParens s!"{printProp this p} ∨ {printProp that p}"
    | .imp this that => addOptionalParens s!"{printProp this p} → {printProp that p}"


#eval (P.imp (P.or (P.and (P.atom "P") (P.atom "Q")) (P.atom "R")) (P.and (P.atom "P") (P.or (P.atom "Q") (P.atom "R"))))
#eval printProp (P.imp (P.or (P.and (P.atom "P") (P.atom "Q")) (P.atom "R")) (P.and (P.atom "P") (P.or (P.atom "Q") (P.atom "R"))))

def toStringTactic (t: T): String :=
  match t with
    | .intro => "INTRO"
    | .apply h => s!"APPLY {h}"
    | .exact h => s!"EXACT {h}"
    | .constructor => "CONSTRUCTOR"
    | .cases h => s!"CASES {h}"
    | .left => s!"LEFT"
    | .right => s!"RIGHT"

instance: ToString T where
  toString := toStringTactic

def toStringGoal [Map α Nat P] (g: G α): String :=
  let lines := (Map.iter g.hyp).map ((λ ((n, p): Nat × P) =>
    s!"{n}: {p}"
  ): (Nat × P) → String)
  let lines := lines ++ [s!"⊢ {g.goal}"]
  String.intercalate "\n" lines

instance [Map α Nat P]: ToString (G α)  where
  toString := toStringGoal
