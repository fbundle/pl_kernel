import PropLogicKernel.Kernel

namespace PropLogicKernel.Auto


def getAllAtoms (p: P): List String :=
  let rec loop (nameList: List String) (p: P): List String :=
    match p with
      | .var name => nameList.insert name -- insert without duplicate
      | .and this that => loop (loop nameList this) that
      | .or this that => loop (loop nameList this) that
      | .imp this that => loop (loop nameList this) that
      | _ => nameList
  loop [] p

def addLEMs [Map g Nat P] (g: G α) : G α :=
  sorry




end PropLogicKernel.Auto
