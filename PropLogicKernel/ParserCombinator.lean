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

def parseConcat (p1: ParseFunc α) (p2: ParseFunc β): ParseFunc (α × β) :=
  let parse (xs: List Char): Option ((α × β) × List Char) := do
    let (a, xs) := ← p1 xs
    let (b, xs) := ← p2 xs
    return ((a, b), xs)
  parse

infix:60 " ++ " => parseConcat

def parseEither (p1: ParseFunc α) (p2: ParseFunc α): ParseFunc α :=
  let parse (xs: List Char): Option (α × List Char) :=
    match p1 xs with
      | some (a1, xs) => some (a1, xs)
      | none =>
        match p2 xs with
          | some (a2, xs) => some (a2, xs)
          | none => none
  parse

infix:50 " || " => parseEither

def parseAnyWS (xs: List Char): Option (Unit × List Char) :=
  match xs with
    | [] => some ((), xs)
    | x :: rest =>
      if ¬ x.isWhitespace then
        some ((), xs)
      else
        parseAnyWS rest

def parseChar (ch: Char) (xs: List Char): Option (Char × List Char) :=
  match xs with
    | [] => none
    | x :: rest =>
      if x == ch then
        some (ch, rest)
      else
        none




end PropLogicKernel.Parser
