import PropLogicKernel.Basic

def toString (p: P): String :=
  match p with
    | .false => "False"
    | .atom name => name
    | .not this => s!"¬ {toString this}"
    | .and this that => s!"({toString this} ∧ {toString that})"
    | .or this that => s!"({toString this} ∨ {toString that})"
    | .imp this that => s!"({toString this} → {toString that})"

instance: ToString P where
  toString := toString

def print (p: P) (parent: Option P := none): String :=
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
    | .not this => s!"¬ {print this p}"
    | .and this that => addOptionalParens s!"{print this p} ∧ {print that p}"
    | .or this that => addOptionalParens s!"{print this p} ∨ {print that p}"
    | .imp this that => addOptionalParens s!"{print this p} → {print that p}"


#eval (P.imp (P.or (P.and (P.atom "P") (P.atom "Q")) (P.atom "R")) (P.and (P.atom "P") (P.or (P.atom "Q") (P.atom "R"))))
#eval print (P.imp (P.or (P.and (P.atom "P") (P.atom "Q")) (P.atom "R")) (P.and (P.atom "P") (P.or (P.atom "Q") (P.atom "R"))))
