import PropLogicKernel.Basic
import PropLogicKernel.Printer

namespace PropLogicKernel.ParserCombinator


def ParseFunc α := List Char → Option (α × List Char)

def concatParseFunc (p1: ParseFunc α) (p2: ParseFunc β) (xs1: List Char): Option ((α × β) × List Char) := do
  let (a, xs2) ← p1 xs1
  let (b, xs3) ← p2 xs2
  return ((a, b), xs3)

infixr:60 " ++ " => concatParseFunc

def eitherParseFunc (p1: ParseFunc α) (p2: ParseFunc α) (xs: List Char): Option (α × List Char) := do
  match p1 xs with
    | some (a1, xs) => some (a1, xs)
    | none =>
      match p2 xs with
        | some (a2, xs) => some (a2, xs)
        | none => none

infixr:50 " || " => eitherParseFunc

def mapParseFunc (p: ParseFunc α) (m: α → β) (xs: List Char): Option (β × List Char) := do
  let (a, xs) ← p xs
  return (m a, xs)

/--
def parseAnyWS (xs: List Char): Option (Unit × List Char) :=
  match xs with
    | [] => some ((), xs)
    | x :: rest =>
      if ¬ x.isWhitespace then
        some ((), xs)
      else
        parseAnyWS rest
--/

def parseFail (xs: List Char): Option (α × List Char) := none

def parseChar (ch: Char) (xs: List Char): Option (Char × List Char) :=
  match xs with
    | [] => none
    | x :: rest =>
      if x == ch then
        some (ch, rest)
      else
        none

partial def listParseFunc (p: ParseFunc α) (xs: List Char): Option (List α × List Char) :=
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
-- Atom ::= Var | "(" Imp ")"

namespace PropLogicKernel.Parser

open PropLogicKernel.ParserCombinator
open PropLogicKernel.Basic

def ParsePropFunc := ParseFunc P

def parseName (xs: List Char): Option (String × List Char) :=
  let chList: List Char := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".toList
  let pList: List (ParseFunc Char) := chList.map parseChar
  -- p1: parse any characters in chList
  let p1: ParseFunc Char := pList.foldl eitherParseFunc parseFail
  -- p2:
  let p2: ParseFunc (List Char) := listParseFunc p1
  let p3: ParseFunc String := mapParseFunc p2 String.ofList

  p3 xs

-- Var
def parseVar: ParsePropFunc := mapParseFunc parseName P.var


def makeRightAssocF (f: P → P → P) (left: P) (rightList: List P): P :=
    match rightList with
      | [] => left
      | p :: rest => f left (makeRightAssocF f p rest)


mutual

-- "(" Imp ")"
partial def parseImpWithParens: ParsePropFunc := mapParseFunc ((parseChar '(') ++ parseImp ++ (parseChar ')')) (λ (_, p, _) => p)

-- Atom ::= Var | "(" Imp ")"
partial def parseAtom: ParsePropFunc := parseVar || parseImpWithParens

-- Not  ::= "¬" Not | Atom
partial def parseNot: ParsePropFunc := mapParseFunc ((parseChar '¬') ++ parseNot) (λ (_, p) => P.imp p P.fals) || parseAtom


-- B := A (ch B)?
partial def makeRightAssocParseFunc (parseA: ParsePropFunc) (ch: Char) (mk: P → List P → P) (xs: List Char): Option (P × List Char) := do
  let parseB := makeRightAssocParseFunc parseA ch mk

  let (left, xs) ← parseA xs

  let rightList := mapParseFunc ((parseChar ch) ++ parseB) (λ (_, p) => p)
  let (rightList, xs) ← (listParseFunc rightList) xs

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


#eval parseImpWithParens ("( A → B )".toList.filter (λ x => ¬ x.isWhitespace))
#eval parseProp? "A ∧ B → B ∧ A"
#eval parseProp? "(A → B) ∧ ¬ B → ¬ A"
#eval parseProp? "A → (A → B) → (A → C) → (B ∨ C → D) → D"
#eval parseProp? "¬¬P → P"

end PropLogicKernel.Parser
