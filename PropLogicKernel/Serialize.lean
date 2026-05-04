import PropLogicKernel.Kernel
import PropLogicKernel.Printer

namespace PropLogicKernel.Serialize

def toStringPropInGoal [Map α Nat P] (g: G α): String × List (Nat × String) :=
  let goal := s!"⊢ {g.goal}"
  let hyp := (Map.iter g.hyp).map (λ (n, p) =>
    (n, s!"{p}")
  : Nat × P → Nat × String)

  (goal, hyp)





end PropLogicKernel.Serialize
