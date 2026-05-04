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

instance[BEq α]: Map (ListMap α β) α β  where
  empty := []
  set := λ (map: ListMap α β) (key: α) (val: β) => (key, val) :: map
  iter := λ (map: ListMap α β) => map
  get? := ListMap.get?

end PropLogicKernel.ListMap
