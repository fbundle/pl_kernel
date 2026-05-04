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

-- make goal into a string with unique hypotheses
def canonicalizeGoal [Ctx α] (g: G α): G (ListMap Nat P) :=
  let hypList: List P := (Ctx.iter g.hyp).map (λ (_, p) => p: Nat × P → P)
  let hypList := hypList.mergeSort (λ a b => (compare a b).isLE)
  let hypList := eraseAdjacentDups hypList

  let hypList: List (Nat × P) := List.zip (List.range hypList.length) hypList

  {
    hyp := {data := hypList},
    goal := g.goal,
  }

def getAllAvailTactics [Ctx α] (g: G α) : List T :=
  let g1 := canonicalizeGoal g

  let tacticList: List T := []

  let tacticList := match g.goal with
    | (.imp _ _) => T.intro :: tacticList
    | (.and _ _) => T.constructor :: tacticList
    | (.or _ _) => T.left :: T.right :: tacticList
    | _ => tacticList

  -- refine
  let rec loop1 (hyp: List (Nat × P)) (tacticList: List T): List T :=
    match hyp with
      | [] => tacticList
      | (n, _) :: rest =>
        let t := T.refine n
        -- try to resolve t
        match t.resolveGoal? 0 False g with -- it doesn't matter what we set for (vc : Nat) (cl : Bool)
          | none =>
            loop1 rest tacticList -- cannot resolve do nothing
          | some (_, g2s) =>
            match g2s with
              | g2' :: [] =>
                let g2 := canonicalizeGoal g2'
                if g2 == g1 then
                  loop1 rest tacticList -- infinite loop
                else
                  loop1 rest (t :: tacticList) -- resolve ok, add t and loop
              | _ =>
                loop1 rest (t :: tacticList) -- resolve ok, add t and loop



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


end PropLogicKernel.Auto
