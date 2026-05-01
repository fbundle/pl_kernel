

from pydantic import BaseModel


class Prop(BaseModel):
    ...

class Name(Prop):
    name: str

class Not(Prop):
    this: Prop

class And(Prop):
    left: Prop
    right: Prop

class Or(Prop):
    left: Prop
    right: Prop

class Imp(Prop):
    left: Prop
    right: Prop

class Fals(Prop):
    ...

def _Prop_priority(t: Prop | None) -> int:
    if t is None:
        return 999
    # Imp Or And Not
    if isinstance(t, Name):
        return 0
    elif isinstance(t, Not):
        return 1
    elif isinstance(t, And):
        return 2
    elif isinstance(t, Or):
        return 3
    elif isinstance(t, Imp):
        return 4
    elif isinstance(t, Fals):
        return 0
    else:
        raise NotImplementedError

def to_string(t: Prop, parent: Prop | None = None) -> str:
    # order
    # Imp Or And Not
    if isinstance(t, Name):
        return t.name
    elif isinstance(t, Not):
        return f"¬{to_string(t.this, parent=t)}"
    elif isinstance(t, And):
        s = f"{to_string(t.left, parent=t)} ∧ {to_string(t.right, parent=t)}"
        if _Prop_priority(parent) <= _Prop_priority(t):
            s = f"({s})"
        return s
    elif isinstance(t, Or):
        s = f"{to_string(t.left, parent=t)} ∨ {to_string(t.right, parent=t)}"
        if _Prop_priority(parent) <= _Prop_priority(t):
            s = f"({s})"
        return s
    elif isinstance(t, Imp):
        s = f"{to_string(t.left, parent=t)} → {to_string(t.right, parent=t)}"
        if _Prop_priority(parent) <= _Prop_priority(t):
            s = f"({s})"
        return s
    elif isinstance(t, Fals):
        return "False"
    else:
        raise NotImplementedError

if __name__ == "__main__":
    A = Name(name="A")
    B = Name(name="B")
    C = Name(name="C")

    x = Imp(
        left=And(left=Or(left=A, right=B), right=C),
        right=Or(left=And(left=A, right=B), right=C),
    )
    print(to_string(x))