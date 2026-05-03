import PropLogicKernel.Basic

namespace PropLogicKernel.Parser

open PropLogicKernel.Basic

/--
Imp  ::= Or ("->" Imp)?        // right
Or   ::= And ("∨" Or)?         // right
And  ::= Not ("∧" And)?        // right
Not  ::= "¬" Not | Atom
Atom ::= variable | "(" Imp ")"


--/



def ParseFunc α := List Char → Option (α × List Char)

def parseConcat (p1: ParseFunc α) (p2: ParseFunc β) (xs: List Char): Option ((α × β) × List Char) := do
  let (a, xs) ← p1 xs
  let (b, xs) ← p2 xs
  return ((a, b), xs)

infix:60 " ++ " => parseConcat

def parseEither (p1: ParseFunc α) (p2: ParseFunc α) (xs: List Char): Option (α × List Char) := do
  match p1 xs with
    | some (a1, xs) => some (a1, xs)
    | none =>
      match p2 xs with
        | some (a2, xs) => some (a2, xs)
        | none => none

infix:50 " || " => parseEither

def parseMap (p: ParseFunc α) (m: α → β) (xs: List Char): Option (β × List Char) := do
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

partial def parseMany (p: ParseFunc α) (xs: List Char): Option (List α × List Char) :=
  let rec loop (ys: Array α) (xs: List Char): Option (List α × List Char) :=
    match p xs with
      | none => some (ys.toList, xs)
      | some (y, newXs) =>
        assert! newXs.length < xs.length
        loop (ys.push y) newXs
  loop #[] xs

def parseName (xs: List Char): Option (String × List Char) :=
  let chList: List Char := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".toList
  let pList: List (ParseFunc Char) := chList.map parseChar
  -- p1: parse any characters in chList
  let p1: ParseFunc Char := pList.foldl parseEither parseFail
  -- p2:
  let p2: ParseFunc (List Char) := parseMany p1
  let p3: ParseFunc String := parseMap p2 String.ofList

  p3 xs






end PropLogicKernel.Parser
