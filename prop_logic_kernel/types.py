

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

def to_string(t: Type) -> str:
    if isinstance(t, Term):
        return t.name
    elif isinstance(t, Not):
        return f"¬{to_string(t)}"
    elif isinstance(t, And):
        return f"({to_string(t.left)} ∧ {to_string(t.right)})"
    elif isinstance(t, Or):
        return f"({to_string(t.left)} ∨ {to_string(t.right)})"
    elif isinstance(t, Imp):
        return f"({to_string(t.left)} → {to_string(t.right)})"
    elif isinstance(t, Fals):
        return "False"
    else:
        raise NotImplementedError