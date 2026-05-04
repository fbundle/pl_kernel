import PropLogicKernel.Kernel
import PropLogicKernel.ListMap

namespace PropLogicKernel.Auto
open PropLogicKernel.ListMap

def getAllAtomsOfProp (p: P) (nameSet: List String): List String :=
  match p with
    | .var name => nameSet.insert name -- insert without duplicate
    | .and this that => getAllAtomsOfProp this (getAllAtomsOfProp that nameSet)
    | .or this that => getAllAtomsOfProp this (getAllAtomsOfProp that nameSet)
    | .imp this that => getAllAtomsOfProp this (getAllAtomsOfProp that nameSet)
    | _ => nameSet

def getAllAtomsOfGoal [Ctx α] (g: G α) : List String :=
  let nameSet := getAllAtomsOfProp g.goal []
  let rec getAllAtomsOfHyp (hyp: List (Nat × P)) (nameSet: List String): List String :=
    match hyp with
      | [] => nameSet
      | (_, p) :: rest =>
        let nameSet := getAllAtomsOfProp p nameSet
        getAllAtomsOfHyp rest nameSet

  let nameSet := getAllAtomsOfHyp (Ctx.iter g.hyp) nameSet
  nameSet

def eraseAdjacentDups [BEq α] (l: List α): List α :=
  match l with
    | [] => l
    | _ :: [] => l
    | x1 :: x2 :: xs =>
      if x1 == x2 then
        eraseAdjacentDups (x2 :: xs)
      else
        x1 :: eraseAdjacentDups (x2 :: xs)

def CanonicalGoal := G (ListMap Nat P) deriving BEq

-- make goal into a string with unique hypotheses
def canonicalizeGoal [Ctx α] (g: G α): CanonicalGoal :=
  let hypList: List P := (Ctx.iter g.hyp).map (λ (_, p) => p: Nat × P → P)
  let hypList := hypList.mergeSort (λ a b => (compare a b).isLE)
  let hypList := eraseAdjacentDups hypList

  let hypList: List (Nat × P) := List.zip (List.range hypList.length) hypList

  {
    hyp := {data := hypList},
    goal := g.goal,
  }

def equalGoals [Ctx α] (g1: G α) (g2: G α): Bool :=
  (canonicalizeGoal g1) == (canonicalizeGoal g2)

def cartesian (xs : List α) (ys : List β) : List (α × β) :=
  let rec loop (prod: List (α × β)) (xs: List α): List (α × β) :=
    match xs with
      | [] => prod
      | x :: rest =>
        loop ((ys.map (λ y => (x, y))) ++ prod) rest

  loop [] xs

#eval cartesian [1, 2, 3] [4, 5, 6]


def getAllAvailTactics [Ctx α] (g: G α) (checkAhead: Bool := True): List T :=
  let tacticList: List T := []

  -- tactic with params
  let nList: List Nat := (Ctx.iter g.hyp).map (λ (n, _) => n)
  let methodList: List (Nat → T) := [T.refine, T.cases]
  let tList: List T := (cartesian methodList nList).map (λ (method, n) => method n)

  let tacticList := if ¬ checkAhead then
    tList ++ tacticList
  else
    let rec loop (tacticList: List T) (tList: List T): List T :=
      match tList with
        | [] => tacticList
        | t :: rest =>
          match t.resolveGoal? 0 false g with
            | none => loop tacticList rest -- cannot resolve, loop
            | some (_, g2 :: []) =>
              if equalGoals g2 g then -- prevent one step loop
                loop tacticList rest
              else
                loop (t :: tacticList) rest -- resolve ok
            | _ => loop (t :: tacticList) rest -- resolve ok

    loop tacticList tList

  -- tactic without params
  let tacticList := match g.goal with
    | (.imp _ _) => T.intro :: tacticList
    | (.and _ _) => T.constructor :: tacticList
    | (.or _ _) => T.left :: T.right :: tacticList
    | _ => tacticList

  tacticList

partial def dfs
  (goalState: α → Bool)
  (transitionFunc: α → β → Option α)
  (neighbourFunc: α → List β)
  (state: α)
: Option α :=
  if goalState state then some state else


  let rec loop (actions: List β): Option α :=
    match actions with
      | [] => none
      | action :: rest =>
        match transitionFunc state action with
          | none => loop rest -- try other branches
          | some nextState =>
            match dfs
              goalState
              transitionFunc
              neighbourFunc
              nextState
            with
              | none => loop rest -- try other branches
              | some goal => goal

  loop (neighbourFunc state)

def autoResolve? [Ctx α] (maxDepth: Nat) (s: S α): Option (List T) := do
  let (_, ts) ← dfs (α := S α × List T) (β := T)
    (goalState := λ ((s, _): S α × List T) => s.stack.length == 0)
    (transitionFunc := λ (s, ts) t => do
      -- no transition at maxDepth
      if ts.length >= maxDepth then failure else

      let s2 ← t.resolveState? (cl := False) s
      -- prevent one step loop
      if s.stack.length == s2.stack.length then
        let g1 ← s.stack.head?
        let g2 ← s2.stack.head?
        if equalGoals g1 g2 then
          failure
        else
          return (s2, t :: ts)
      else
        return (s2, t :: ts)
    )
    (neighbourFunc := λ (s, ts) =>
      -- no neighbourhood at maxDepth
      if ts.length >= maxDepth then [] else
      match s.stack with
        | [] => []
        | g :: _ => getAllAvailTactics g (checkAhead := False)
    )
    (s, [])

  return ts




end PropLogicKernel.Auto
