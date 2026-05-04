import PropLogicKernel.Kernel

namespace PropLogicKernel.Auto


def getAllAtomsOfProp (p: P) (nameSet: List String): List String :=
  match p with
    | .var name => nameSet.insert name -- insert without duplicate
    | .and this that => getAllAtomsOfProp this (getAllAtomsOfProp that nameSet)
    | .or this that => getAllAtomsOfProp this (getAllAtomsOfProp that nameSet)
    | .imp this that => getAllAtomsOfProp this (getAllAtomsOfProp that nameSet)
    | _ => nameSet

def getAllAtomsOfGoal [Map α Nat P] (g: G α) : List String :=
  let nameSet := getAllAtomsOfProp g.goal []
  let rec getAllAtomsOfHyp (hyp: List (Nat × P)) (nameSet: List String): List String :=
    match hyp with
      | [] => nameSet
      | (_, p) :: hyp =>
        let nameSet := getAllAtomsOfProp p nameSet
        getAllAtomsOfHyp hyp nameSet

  let nameSet := getAllAtomsOfHyp (Map.iter g.hyp) nameSet
  nameSet



end PropLogicKernel.Auto
