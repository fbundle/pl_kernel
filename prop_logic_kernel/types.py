

from pydantic import BaseModel


class Type(BaseModel):
    ...

class Term(Type):
    name: str

class Not(Type):
    this: Type

class And(Type):
    left: Type
    right: Type

class Or(Type):
    left: Type
    right: Type

class Imp(Type):
    left: Type
    right: Type

class Fals(Type):
    ...

def _type_priority(t: Type | None) -> int:
    if t is None:
        return 999
    # Imp Or And Not
    if isinstance(t, Term):
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

def to_string(t: Type, parent: Type | None = None) -> str:
    # order
    # Imp Or And Not
    if isinstance(t, Term):
        return t.name
    elif isinstance(t, Not):
        return f"¬{to_string(t.this, parent=t)}"
    elif isinstance(t, And):
        s = f"{to_string(t.left, parent=t)} ∧ {to_string(t.right, parent=t)}"
        if _type_priority(parent) <= _type_priority(t):
            s = f"({s})"
        return s
    elif isinstance(t, Or):
        s = f"{to_string(t.left, parent=t)} ∨ {to_string(t.right, parent=t)}"
        if _type_priority(parent) <= _type_priority(t):
            s = f"({s})"
        return s
    elif isinstance(t, Imp):
        s = f"{to_string(t.left, parent=t)} → {to_string(t.right, parent=t)}"
        if _type_priority(parent) <= _type_priority(t):
            s = f"({s})"
        return s
    elif isinstance(t, Fals):
        return "False"
    else:
        raise NotImplementedError