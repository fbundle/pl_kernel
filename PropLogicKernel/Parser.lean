import PropLogicKernel.Basic

namespace PropLogicKernel.Parser

open PropLogicKernel.Basic

/--
the code below was written by cursor
--/


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
def parseProp? (s : String) : Option P :=
  let s := s.toUpper -- make sure the proposition is in uppercase
  match parseImp (skipWs s.toList) with
  | none => none
  | some (p, _) => some p

def parseTactic? (s: String): Option T :=
  let s := s.trimAscii.toString
  match s with
  | "intro" => some T.intro
  | "constructor" => some T.constructor
  | "left" => some T.left
  | "right" => some T.right
  | "sorry" => some T.sorr
  | _ =>
    if s.startsWith "apply " then
      (s.drop 6).toString |> String.toNat? |>.map T.apply
    else if s.startsWith "exact " then
      (s.drop 6).toString |> String.toNat? |>.map T.exact
    else if s.startsWith "cases " then
      (s.drop 6).toString |> String.toNat? |>.map T.cases
    else if s.startsWith "lem " then
      parseProp? ((s.drop 4).toString) |>.map T.lem
    else if s.startsWith "refine " then
      (s.drop 7).toString |> String.toNat? |>.map T.refine
    else if s.startsWith "new " then
      parseProp? ((s.drop 4).toString) |>.map T.new
    else
      none

end PropLogicKernel.Parser
