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

-- we only set skipOneCycle = True when doing DFS
def getAllAvailTactics [Ctx α] (g: G α) (skipOneCycle: Bool := False): List T :=

  let tacticList: List T := []
  let tacticList := match g.goal with
    | (.imp _ _) => T.intro :: tacticList
    | (.and _ _) => T.constructor :: tacticList
    | (.or _ _) => T.left :: T.right :: tacticList
    | _ => tacticList

  -- refine
  let g1: Option CanonicalGoal :=
    if skipOneCycle then none else canonicalizeGoal g

  let rec loop1 (hyp: List (Nat × P)) (tacticList: List T): List T :=
    match hyp with
      | [] => tacticList
      | (n, _) :: rest =>
        let t := T.refine n
        -- try to resolve t
        let newTacticList: List T :=
          match t.resolveGoal? 0 False g with -- it doesn't matter what we set for (vc : Nat) (cl : Bool)
            | none =>
              tacticList -- cannot resolve do nothing
            | some (_, g2s) =>
              if skipOneCycle then
                (t :: tacticList) -- resolve ok, add t and loop
              else
                match g2s with
                  | g2' :: [] =>
                    if (canonicalizeGoal g2') == g1 then
                      tacticList -- prevent 1-step infinite loop
                    else
                      (t :: tacticList) -- resolve ok, add t and loop
                  | _ =>
                    (t :: tacticList) -- resolve ok, add t and loop

        loop1 rest newTacticList

  let tacticList := loop1 (Ctx.iter g.hyp) tacticList

  -- cases tactic
  let rec loop2 (hyp: List (Nat × P)) (tacticList: List T): List T :=
    match hyp with
      | [] => tacticList
      | (n, p) :: rest =>
        let t := T.cases n
        match p with
          | .and _ _ => loop2 rest (t :: tacticList)
          | .or _ _ => loop2 rest (t :: tacticList)
          -- | .fals => loop2 rest (t :: tacticList) -- we already refine - this is dup
          | _ => loop2 rest tacticList

  let tacticList := loop2 (Ctx.iter g.hyp) tacticList

  tacticList

partial def dfs
  (goalState: α → Bool)
  (transitionFunc: α → β → α)
  (neighbourFunc: α → List β)
  (maxDepth: Nat)
  (state: α)
: Option α :=
  if maxDepth == 0 then none else

  if goalState state then some state else


  let rec loop (actions: List β): Option α :=
    match actions with
      | [] => none
      | action :: rest =>
        match dfs
          goalState
          transitionFunc
          neighbourFunc
          (maxDepth := maxDepth -1)
          (transitionFunc state action)
        with
          | none => loop rest -- try other branches
          | some goal => goal

  loop (neighbourFunc state)




end PropLogicKernel.Auto
