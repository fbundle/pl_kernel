namespace PropLogicKernel.ListMap

class Map (ζ: Type u) (α: Type v) (β: Type w) [BEq α] where
  get? (z: ζ) (key: α): Option β
  set (z: ζ) (key: α) (val: β): ζ
  iter (z: ζ): List (α × β)

def ListMap α β [BEq α] := List (α × β)

def get? [BEq α] (map: ListMap α β) (key: α): Option β :=
  match map with
    | [] => none
    | (k, v) :: xs =>
      if k == key then
        some v
      else
        get? xs key

def set [BEq α] (map: ListMap α β) (key: α) (val: β): ListMap α β :=
  (key, val) :: map

def iter [BEq α] (map: ListMap α β) := map

instance[BEq α]: Map (ListMap α β) α β  where
  get? := get?
  set := set
  iter := iter

def emptyList [BEq α]: ListMap α β := []


end PropLogicKernel.ListMap
