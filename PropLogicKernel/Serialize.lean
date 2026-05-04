
import PropLogicKernel.Kernel
import PropLogicKernel.Printer

namespace PropLogicKernel.Serialize

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
def serializeGoal [Map α Nat P] (g: G α): String :=
  let (goal, hyp) := Printer.toStringPropInGoal g
  let hyp: List String := (hyp.map (λ (_, p) => p))
  let hyp := eraseAdjacentDups (hyp.mergeSort)

  let pList: List String := goal :: hyp

  String.intercalate "\n" pList



end PropLogicKernel.Serialize
