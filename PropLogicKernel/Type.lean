class Map (α: Type) (K: Type) (V: Type) where
  get (k: K): Option V
  set (m: α)(k: K) (v: V): α
  size: Nat
