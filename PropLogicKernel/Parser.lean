import PropLogicKernel.Basic

namespace PropLogicKernel.Parser

open PropLogicKernel.Basic

private def skipWs (cs : List Char) : List Char :=
  cs.dropWhile (·.isWhitespace)

mutual
  /-- Right-associative: `A → B → C` parses as `A → (B → C)`. -/
  partial def parseImp (cs : List Char) : Option (P × List Char) := do
    let (p, cs) ← parseOr cs
    let cs := skipWs cs
    match cs with
    | '→' :: cs =>
      let (q, cs) ← parseImp cs
      some (P.imp p q, cs)
    | _ => some (p, cs)

  /-- Right-associative: `A ∨ B ∨ C` parses as `A ∨ (B ∨ C)`. -/
  partial def parseOr (cs : List Char) : Option (P × List Char) := do
    let (p, cs) ← parseAnd cs
    let cs := skipWs cs
    match cs with
    | '∨' :: cs =>
      let (q, cs) ← parseOr cs
      some (P.or p q, cs)
    | _ => some (p, cs)

  /-- Right-associative: `A ∧ B ∧ C` parses as `A ∧ (B ∧ C)`. -/
  partial def parseAnd (cs : List Char) : Option (P × List Char) := do
    let (p, cs) ← parseUnary cs
    let cs := skipWs cs
    match cs with
    | '∧' :: cs =>
      let (q, cs) ← parseAnd cs
      some (P.and p q, cs)
    | _ => some (p, cs)

  partial def parseUnary (cs : List Char) : Option (P × List Char) := do
    let cs := skipWs cs
    match cs with
    | [] => none
    | '⊥' :: cs => some (P.fals, cs)
    | '(' :: cs => do
      let (p, cs) ← parseImp cs
      let cs := skipWs cs
      match cs with
      | ')' :: cs => some (p, cs)
      | _ => none
    | c :: rest =>
      if c.isAlpha then
        let all := c :: rest
        let idChars := all.takeWhile (·.isAlpha)
        some (P.atom (String.ofList idChars), all.drop idChars.length)
      else
        none
end

/-- Parse a proposition; returns the remainder string (after skipping trailing whitespace). -/
def parseProp? (s : String) : Option (P × String) :=
  match parseImp (skipWs s.toList) with
  | none => none
  | some (p, cs) => some (p, String.ofList (skipWs cs))

end PropLogicKernel.Parser
