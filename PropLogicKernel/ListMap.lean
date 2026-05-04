import PropLogicKernel.Kernel

namespace PropLogicKernel.ListMap

def ListMap α β [BEq α] := List (α × β)

def ListMap.get? [BEq α] (map: ListMap α β) (key: α): Option β :=
  match map with
    | [] => none
    | (k, v) :: xs =>
      if k == key then
        some v
      else
        get? xs key

instance: Ctx (ListMap Nat P) where
  empty := []
  set := λ (map: ListMap Nat P) (key: Nat) (val: P) => (key, val) :: map
  iter := λ (map: ListMap Nat P) => map
  get? := ListMap.get?

end PropLogicKernel.ListMap
