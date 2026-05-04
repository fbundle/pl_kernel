
import PropLogicKernel.Kernel
import PropLogicKernel.ListMap

namespace PropLogicKernel.Serialize

open PropLogicKernel.ListMap

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
def canonicalizeGoal [Map α Nat P] (g: G α): G (ListMap Nat P) :=
  let hypList: List P := (Map.iter g.hyp).map (λ (_, p) => p: Nat × P → P)
  let hypList := hypList.mergeSort (λ a b => (compare a b).isLE)
  let hypList := eraseAdjacentDups hypList

  let hypList: List (Nat × P) := List.zip (List.range hypList.length) hypList

  {
    hyp := hypList,
    goal := g.goal,
  }




end PropLogicKernel.Serialize
