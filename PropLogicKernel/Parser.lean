import PropLogicKernel.Basic
import PropLogicKernel.Printer

namespace PropLogicKernel.ParserCombinator


def ParseFunc α := List Char → Option (α × List Char)

def ParseFunc.concat (p1: ParseFunc α) (p2: ParseFunc β): ParseFunc (α × β) :=
  λ (xs1: List Char) => do
  let (a, xs2) ← p1 xs1
  let (b, xs3) ← p2 xs2
  return ((a, b), xs3)

infixr:60 " ++ " => ParseFunc.concat

def ParseFunc.orElse (p1: ParseFunc α) (p2: ParseFunc α): ParseFunc α :=
  λ (xs: List Char) => do
  -- p1 xs <|> p2 xs
  match p1 xs with
    | some (a1, xs) => some (a1, xs)
    | none => p2 xs

infixr:50 " || " => ParseFunc.orElse

def ParseFunc.map (p: ParseFunc α) (m: α → β): ParseFunc β :=
  λ (xs: List Char) => do
    let (a, xs) ← p xs
    return (m a, xs)

def parseFail: ParseFunc α := λ _ => none

def parseExact (ch: Char): ParseFunc Char :=
  λ (xs: List Char) =>
    match xs with
      | [] => none
      | x :: rest =>
        if x == ch then
          some (ch, rest)
        else
          none


partial def ParseFunc.repeat (p: ParseFunc α) (xs: List Char): Option (List α × List Char) :=
  let rec loop (ys: Array α) (xs: List Char): Option (List α × List Char) :=
    match p xs with
      | none => some (ys.toList, xs)
      | some (y, xs1) =>
        assert! xs1.length < xs.length
        loop (ys.push y) xs1
  loop #[] xs


end PropLogicKernel.ParserCombinator


-- grammar (not left recursive)

-- Imp  ::= Or ("->" Imp)?        // right
-- Or   ::= And ("∨" Or)?         // right
-- And  ::= Not ("∧" And)?        // right
-- Not  ::= "¬" Not | Atom
-- Atom ::= Var | ⊥ | "(" Imp ")"

namespace PropLogicKernel.Parser

open PropLogicKernel.ParserCombinator
open PropLogicKernel.Basic

def ParsePropFunc := ParseFunc P

def parseNonEmptyString (chList: List Char) (xs: List Char): Option (String × List Char) := do
  let pList: List (ParseFunc Char) := chList.map parseExact
  -- p1: parse any characters in chList
  let p1: ParseFunc Char := pList.foldl ParseFunc.orElse parseFail
  -- p2:
  let p2: ParseFunc (List Char) := p1.repeat
  let p3: ParseFunc String := p2.map String.ofList

  let (s, rest) ← p3 xs
  if s.length == 0 then
    failure
  else
    return (s, rest)

def parseName: ParseFunc String := parseNonEmptyString "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".toList

-- Var
def parseVar: ParsePropFunc := parseName.map P.var

-- Fals
def parseFals: ParsePropFunc := (parseExact '⊥').map (λ _ => P.fals)


def makeRightAssocF (f: P → P → P) (left: P) (rightList: List P): P :=
    match rightList with
      | [] => left
      | p :: rest => f left (makeRightAssocF f p rest)


mutual

-- Atom ::= Var | ⊥ | "(" Imp ")"
partial def parseAtom: ParsePropFunc := parseVar || parseFals || ((parseExact '(') ++ parseImp ++ (parseExact ')')).map (λ (_, p, _) => p)

-- Not  ::= "¬" Not | Atom
partial def parseNot: ParsePropFunc := ((parseExact '¬') ++ parseNot).map (λ (_, p) => P.imp p P.fals) || parseAtom


-- B := A (sep B)?
partial def makeRightAssocParseFunc (parseA: ParsePropFunc) (sep: Char) (mk: P → List P → P) (xs: List Char): Option (P × List Char) := do
  let parseB := makeRightAssocParseFunc parseA sep mk

  let (left, xs) ← parseA xs

  let parseSepB := ((parseExact sep) ++ parseB).map (λ (_, p) => p)
  let (rightList, xs) ← parseSepB.repeat xs

  return (mk left rightList, xs)


-- And  ::= Not ("∧" And)?
partial def parseAnd: ParsePropFunc := makeRightAssocParseFunc parseNot '∧' (makeRightAssocF P.and)

-- Or   ::= And ("∨" Or)?
partial def parseOr: ParsePropFunc := makeRightAssocParseFunc parseAnd '∨' (makeRightAssocF P.or)

-- Imp  ::= Or ("→" Imp)?
partial def parseImp: ParsePropFunc := makeRightAssocParseFunc parseOr '→' (makeRightAssocF P.imp)

end

def parseProp? (input: String): Option P := do
  let chList := input.toList.filter (λ x => ¬ x.isWhitespace)
  let (p, _) ← parseImp chList
  return p

#eval parseProp? "A → ⊥"
#eval parseProp? "A ∧ B → B ∧ A"
#eval parseProp? "(A → B) ∧ ¬ B → ¬ A"
#eval parseProp? "A → (A → B) → (A → C) → (B ∨ C → D) → D"
#eval parseProp? "¬¬P → P"

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
