from __future__ import annotations

import random
from dataclasses import dataclass

from .puzzle import Puzzle


class Prop:
    def precedence(self) -> int:
        raise NotImplementedError

    def render(self, parent_prec: int = 10) -> str:
        raise NotImplementedError


@dataclass(frozen=True, slots=True)
class Atom(Prop):
    name: str

    def precedence(self) -> int:
        return 0

    def render(self, parent_prec: int = 10) -> str:
        return self.name


@dataclass(frozen=True, slots=True)
class Bot(Prop):
    def precedence(self) -> int:
        return 0

    def render(self, parent_prec: int = 10) -> str:
        return "⊥"


@dataclass(frozen=True, slots=True)
class And(Prop):
    left: Prop
    right: Prop

    def precedence(self) -> int:
        return 1

    def render(self, parent_prec: int = 10) -> str:
        s = f"{self.left.render(self.precedence())} ∧ {self.right.render(self.precedence())}"
        return f"({s})" if self.precedence() >= parent_prec else s


@dataclass(frozen=True, slots=True)
class Or(Prop):
    left: Prop
    right: Prop

    def precedence(self) -> int:
        return 2

    def render(self, parent_prec: int = 10) -> str:
        s = f"{self.left.render(self.precedence())} ∨ {self.right.render(self.precedence())}"
        return f"({s})" if self.precedence() >= parent_prec else s


@dataclass(frozen=True, slots=True)
class Imp(Prop):
    left: Prop
    right: Prop

    def precedence(self) -> int:
        return 3

    def render(self, parent_prec: int = 10) -> str:
        s = f"{self.left.render(self.precedence())} → {self.right.render(self.precedence())}"
        return f"({s})" if self.precedence() >= parent_prec else s


@dataclass(frozen=True)
class GenerateSettings:
    """
    Two difficulty knobs:
    - `num_vars`: how many distinct atom names are available (A, B, C, ...)
    - `depth`: how deep the goal expression can nest (`∧`/`∨`) and how many `intro`s we add
    """

    num_vars: int = 4
    depth: int = 6
    seed: int | None = None
    max_attempts: int = 1


def _vars(num_vars: int) -> list[str]:
    base = [chr(ord("A") + i) for i in range(max(0, num_vars))]
    return base if base else ["A"]


def _gen_goal(rng: random.Random, leaves: list[str], depth: int) -> Prop:
    if depth <= 0 or rng.random() < 0.35:
        return Atom(rng.choice(leaves))
    ctor = rng.choice([And, Or])
    return ctor(_gen_goal(rng, leaves, depth - 1), _gen_goal(rng, leaves, depth - 1))


def _build_statement(assumptions: list[str], goal: Prop) -> Prop:
    p: Prop = goal
    for a in reversed(assumptions):
        p = Imp(Atom(a), p)
    return p


def _proof_for_goal(goal: Prop, atom_to_hyp: dict[str, int], rng: random.Random) -> list[str]:
    if isinstance(goal, Atom):
        return [f"exact {atom_to_hyp[goal.name]}"]
    if isinstance(goal, And):
        return ["constructor", *_proof_for_goal(goal.left, atom_to_hyp, rng), *_proof_for_goal(goal.right, atom_to_hyp, rng)]
    if isinstance(goal, Or):
        # choose a side and prove it
        if rng.random() < 0.5:
            return ["left", *_proof_for_goal(goal.left, atom_to_hyp, rng)]
        return ["right", *_proof_for_goal(goal.right, atom_to_hyp, rng)]
    if isinstance(goal, Imp):
        # shouldn't happen (our goals are built from leaves with ∧/∨), but handle anyway
        return ["intro", *_proof_for_goal(goal.right, {**atom_to_hyp, "_": max(atom_to_hyp.values(), default=-1) + 1}, rng)]
    if isinstance(goal, Bot):
        raise ValueError("cannot generate a closed proof of ⊥ without classical features")
    raise TypeError(f"unknown Prop node: {type(goal)}")


def generate_puzzle(settings: GenerateSettings = GenerateSettings()) -> Puzzle:
    """
    Generate a provable proposition and a concrete tactic proof script.
    """
    rng = random.Random(settings.seed)
    atoms = _vars(settings.num_vars)

    # More depth => more assumptions + deeper ∧/∨ goal.
    num_assumptions = max(1, min(len(atoms), (settings.depth + 1) // 2))
    assumptions = atoms[:]
    rng.shuffle(assumptions)
    assumptions = assumptions[:num_assumptions]

    goal = _gen_goal(rng, assumptions, settings.depth)
    statement_prop = _build_statement(assumptions, goal)
    statement = statement_prop.render()

    # Hypothesis indices are assigned in `intro` order starting from 0.
    proof: list[str] = ["intro"] * len(assumptions)
    # Hypotheses are numbered in the same order they are introduced by `intro`.
    # Given how `_build_statement` wraps implications, this matches `assumptions` order.
    atom_to_hyp = {a: i for i, a in enumerate(assumptions)}
    proof.extend(_proof_for_goal(goal, atom_to_hyp, rng))

    return Puzzle(
        statement=statement,
        proof=proof,
        settings={
            "num_vars": settings.num_vars,
            "depth": settings.depth,
            "seed": settings.seed,
        },
    )

