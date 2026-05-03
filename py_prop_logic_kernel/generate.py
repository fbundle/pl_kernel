from __future__ import annotations

import hashlib
import random
from dataclasses import dataclass

from .puzzle import Puzzle


class Prop:
    def precedence(self) -> int:
        raise NotImplementedError

    def render(self, parent_prec: int = 10) -> str:
        raise NotImplementedError

    def atoms(self) -> frozenset[str]:
        raise NotImplementedError


@dataclass(frozen=True, slots=True)
class Atom(Prop):
    name: str

    def precedence(self) -> int:
        return 0

    def render(self, parent_prec: int = 10) -> str:
        return self.name

    def atoms(self) -> frozenset[str]:
        return frozenset({self.name})


@dataclass(frozen=True, slots=True)
class Bot(Prop):
    def precedence(self) -> int:
        return 0

    def render(self, parent_prec: int = 10) -> str:
        return "⊥"

    def atoms(self) -> frozenset[str]:
        return frozenset()


@dataclass(frozen=True, slots=True)
class And(Prop):
    left: Prop
    right: Prop

    def precedence(self) -> int:
        return 1

    def render(self, parent_prec: int = 10) -> str:
        s = f"{self.left.render(self.precedence())} ∧ {self.right.render(self.precedence())}"
        return f"({s})" if self.precedence() >= parent_prec else s

    def atoms(self) -> frozenset[str]:
        return self.left.atoms() | self.right.atoms()


@dataclass(frozen=True, slots=True)
class Or(Prop):
    left: Prop
    right: Prop

    def precedence(self) -> int:
        return 2

    def render(self, parent_prec: int = 10) -> str:
        s = f"{self.left.render(self.precedence())} ∨ {self.right.render(self.precedence())}"
        return f"({s})" if self.precedence() >= parent_prec else s

    def atoms(self) -> frozenset[str]:
        return self.left.atoms() | self.right.atoms()


@dataclass(frozen=True, slots=True)
class Imp(Prop):
    left: Prop
    right: Prop

    def precedence(self) -> int:
        return 3

    def render(self, parent_prec: int = 10) -> str:
        s = f"{self.left.render(self.precedence())} → {self.right.render(self.precedence())}"
        return f"({s})" if self.precedence() >= parent_prec else s

    def atoms(self) -> frozenset[str]:
        return self.left.atoms() | self.right.atoms()


def _props_equal(a: Prop, b: Prop) -> bool:
    if type(a) is not type(b):
        return False
    if isinstance(a, Atom):
        return a.name == b.name  # type: ignore[misc]
    if isinstance(a, Bot):
        return True
    if isinstance(a, (And, Or, Imp)):
        return _props_equal(a.left, b.left) and _props_equal(a.right, b.right)  # type: ignore[misc]
    return False


@dataclass(frozen=True)
class GenerateSettings:
    """
    - `num_vars`: count of atomic names (`A`…`Z`, then `Z0`, `Z1`, … shuffled).
    - `depth`: recursion cap for goals (∧/∨/Atom and optional `Atom → …` outer goals).
    - `max_attempts`: resample when proof synthesis fails.

    Validate puzzles against the Lean kernel separately (e.g. `Puzzle.check`, `examples/check_puzzles.py`).

    Classical proof search / template families are not implemented (separate solver).
    """

    num_vars: int = 4
    depth: int = 6
    seed: int | None = None
    max_attempts: int = 48


def _vars(num_vars: int, rng: random.Random) -> list[str]:
    if num_vars <= 0:
        return ["A"]
    out: list[str] = []
    for i in range(num_vars):
        if i < 26:
            out.append(chr(ord("A") + i))
        else:
            out.append(f"Z{i - 26}")
    rng.shuffle(out)
    return out


def _pick_leaf(rng: random.Random, leaves: list[str], *, repeat_bias: float) -> str:
    if not leaves:
        return "A"
    if rng.random() < repeat_bias:
        return rng.choice(leaves)
    u = rng.random()
    w = [repeat_bias + (1.0 - repeat_bias) * (1.0 / len(leaves)) for _ in leaves]
    s = sum(w)
    t = u * s
    acc = 0.0
    for c, wi in zip(leaves, w, strict=True):
        acc += wi
        if t <= acc:
            return c
    return leaves[-1]


def _gen_goal(
    rng: random.Random,
    leaves: list[str],
    depth: int,
    leaf_p: float,
    *,
    repeat_bias: float,
    and_w: float,
    or_w: float,
    imp_w: float,
) -> Prop:
    if depth <= 0 or rng.random() < leaf_p:
        return Atom(_pick_leaf(rng, leaves, repeat_bias=repeat_bias))
    total = and_w + or_w + imp_w
    r = rng.random() * total
    if r < and_w:
        dl = rng.randint(0, depth - 1)
        dr = rng.randint(0, depth - 1)
        return And(
            _gen_goal(rng, leaves, dl, leaf_p, repeat_bias=repeat_bias, and_w=and_w, or_w=or_w, imp_w=imp_w),
            _gen_goal(rng, leaves, dr, leaf_p, repeat_bias=repeat_bias, and_w=and_w, or_w=or_w, imp_w=imp_w),
        )
    if r < and_w + or_w:
        dl = rng.randint(0, depth - 1)
        dr = rng.randint(0, depth - 1)
        return Or(
            _gen_goal(rng, leaves, dl, leaf_p, repeat_bias=repeat_bias, and_w=and_w, or_w=or_w, imp_w=imp_w),
            _gen_goal(rng, leaves, dr, leaf_p, repeat_bias=repeat_bias, and_w=and_w, or_w=or_w, imp_w=imp_w),
        )
    # Imp: keep antecedent a single atom so one `intro` matches the kernel.
    la = rng.randint(0, max(0, depth - 2))
    right = _gen_goal(
        rng, leaves, la, min(0.55, leaf_p + 0.12), repeat_bias=repeat_bias, and_w=and_w, or_w=or_w, imp_w=imp_w
    )
    return Imp(Atom(rng.choice(leaves)), right)


def _build_statement(assumptions: list[Prop], goal: Prop) -> Prop:
    p: Prop = goal
    for a in reversed(assumptions):
        p = Imp(a, p)
    return p


def _gen_assumption(rng: random.Random, atoms: list[str]) -> Prop:
    a, b = (rng.choice(atoms), rng.choice(atoms)) if len(atoms) == 1 else rng.sample(atoms, 2)
    r = rng.random()
    if r < 0.42:
        return Atom(rng.choice(atoms))
    if r < 0.68:
        return Imp(Atom(a), Atom(b))
    if r < 0.86:
        return And(Atom(a), Atom(b))
    return Or(Atom(a), Atom(b))


def _force_swapped_or_goal(assumptions: list[Prop]) -> Prop | None:
    for p in assumptions:
        if isinstance(p, Or) and isinstance(p.left, Atom) and isinstance(p.right, Atom):
            return Or(p.right, p.left)
    return None


def _eliminate_all_and(hyp: dict[int, Prop], next_id: list[int], tactics: list[str]) -> None:
    """
    Emit `cases` for each ∧ hypothesis once. The kernel keeps the original ∧ entry in the map,
    so we must track indices already split — otherwise this loop never terminates and memory explodes.
    """
    already_split: set[int] = set()
    # Hard cap: number of ∧ hypotheses we can ever split is finite; this bounds work and memory.
    for _ in range(4096):
        found: int | None = None
        for i, p in hyp.items():
            if i in already_split:
                continue
            if isinstance(p, And):
                found = i
                break
        if found is None:
            return
        already_split.add(found)
        p = hyp[found]
        assert isinstance(p, And)
        tactics.append(f"cases {found}")
        ia = next_id[0]
        next_id[0] += 1
        ib = next_id[0]
        next_id[0] += 1
        hyp[ia] = p.left
        hyp[ib] = p.right
    raise RuntimeError("_eliminate_all_and exceeded iteration cap (internal error)")


def _try_exact_atom(goal: Atom, hyp: dict[int, Prop]) -> int | None:
    for i, p in hyp.items():
        if _props_equal(p, goal):
            return i
    return None


def _try_apply_imp(goal: Prop, hyp: dict[int, Prop]) -> tuple[int, Prop] | None:
    for i, p in hyp.items():
        if isinstance(p, Imp) and _props_equal(p.right, goal):
            return i, p.left
    return None


def _prove_atom(
    goal: Prop,
    hyp: dict[int, Prop],
    next_id: list[int],
    tactics: list[str],
    rng: random.Random,
    fuel: int,
) -> bool:
    if fuel <= 0:
        return False
    if not isinstance(goal, Atom):
        return _prove_proposition(goal, hyp, next_id, tactics, rng, fuel)
    g: Atom = goal
    f = fuel
    # Iterative `apply` chain: avoids Python stack blowup on long/cyclic implication paths.
    while f > 0:
        j = _try_exact_atom(g, hyp)
        if j is not None:
            tactics.append(f"exact {j}")
            return True
        app = _try_apply_imp(g, hyp)
        if app is None:
            return False
        i, ante = app
        tactics.append(f"apply {i}")
        f -= 1
        if isinstance(ante, Atom):
            g = ante
            continue
        return _prove_proposition(ante, hyp, next_id, tactics, rng, f)
    return False


def _prove_proposition(
    goal: Prop, hyp: dict[int, Prop], next_id: list[int], tactics: list[str], rng: random.Random, fuel: int
) -> bool:
    if fuel <= 0:
        return False
    if isinstance(goal, Atom):
        return _prove_atom(goal, hyp, next_id, tactics, rng, fuel)
    if isinstance(goal, Bot):
        app = _try_apply_imp(goal, hyp)
        if app is None:
            return False
        i, ante = app
        tactics.append(f"apply {i}")
        return _prove_proposition(ante, hyp, next_id, tactics, rng, fuel - 1)
    if isinstance(goal, And):
        tactics.append("constructor")
        if rng.random() < 0.5:
            return _prove_proposition(goal.left, hyp, next_id, tactics, rng, fuel - 1) and _prove_proposition(
                goal.right, hyp, next_id, tactics, rng, fuel - 1
            )
        return _prove_proposition(goal.right, hyp, next_id, tactics, rng, fuel - 1) and _prove_proposition(
            goal.left, hyp, next_id, tactics, rng, fuel - 1
        )
    if isinstance(goal, Or):
        if rng.random() < 0.5:
            tactics.append("left")
            return _prove_proposition(goal.left, hyp, next_id, tactics, rng, fuel - 1)
        tactics.append("right")
        return _prove_proposition(goal.right, hyp, next_id, tactics, rng, fuel - 1)
    if isinstance(goal, Imp):
        tactics.append("intro")
        idx = next_id[0]
        next_id[0] += 1
        hyp = dict(hyp)
        hyp[idx] = goal.left
        inner = goal.right
        if isinstance(goal.left, And):
            tactics.append(f"cases {idx}")
            p = goal.left
            assert isinstance(p, And)
            ia = next_id[0]
            next_id[0] += 1
            ib = next_id[0]
            next_id[0] += 1
            hyp[ia] = p.left
            hyp[ib] = p.right
        _eliminate_all_and(hyp, next_id, tactics)
        return _prove_proposition(inner, hyp, next_id, tactics, rng, fuel - 1)
    return False


def _prove_or_with_hyp_elim(
    goal: Or,
    hyp: dict[int, Prop],
    next_id: list[int],
    tactics: list[str],
    rng: random.Random,
    fuel: int,
) -> bool:
    if _prove_proposition(goal, hyp, next_id, tactics, rng, fuel):
        return True
    cands = [(i, p) for i, p in hyp.items() if isinstance(p, Or)]
    rng.shuffle(cands)
    for i, disj in cands:
        if not isinstance(disj, Or):
            continue
        m = next_id[0]
        hyp1 = {**hyp, m: disj.left}
        hyp2 = {**hyp, m + 1: disj.right}
        t1: list[str] = []
        t2: list[str] = []
        c1 = [m + 2]
        c2 = [m + 2]
        if not _prove_proposition(goal, hyp1, c1, t1, rng, fuel):
            continue
        if not _prove_proposition(goal, hyp2, c2, t2, rng, fuel):
            continue
        next_id[0] = max(c1[0], c2[0])
        tactics.append(f"cases {i}")
        tactics.extend(t1)
        tactics.extend(t2)
        return True
    return False


# Bounds apply-chains (cycles in hyps) and deep splits; keeps memory/stack predictable for RL batches.
_PROOF_FUEL = 512


def _synthesize_proof(assumptions: list[Prop], goal: Prop, rng: random.Random) -> list[str] | None:
    tactics: list[str] = []
    hyp: dict[int, Prop] = {}
    next_id = [0]
    for a in assumptions:
        tactics.append("intro")
        idx = next_id[0]
        next_id[0] += 1
        hyp[idx] = a
    _eliminate_all_and(hyp, next_id, tactics)
    if isinstance(goal, Or):
        ok = _prove_or_with_hyp_elim(goal, hyp, next_id, tactics, rng, _PROOF_FUEL)
    else:
        ok = _prove_proposition(goal, hyp, next_id, tactics, rng, _PROOF_FUEL)
    return tactics if ok else None


def _statement_fingerprint(stmt: str) -> str:
    return hashlib.sha256(stmt.encode("utf-8")).hexdigest()[:16]


def _try_generate_once(rng: random.Random, settings: GenerateSettings) -> tuple[Puzzle | None, str | None]:
    atoms = _vars(settings.num_vars, rng)
    cap = min(len(atoms), max(1, settings.depth + 1))
    num_assumptions = rng.randint(1, cap)
    assumptions = [_gen_assumption(rng, atoms) for _ in range(num_assumptions)]

    forced = _force_swapped_or_goal(assumptions)
    leaf_p = rng.uniform(0.1, 0.52)
    repeat_bias = rng.uniform(0.0, 0.55)
    and_w = rng.betavariate(2.0, 2.0)
    or_w = rng.betavariate(2.0, 2.0)
    imp_w = rng.betavariate(1.2, 2.2)

    if forced is not None:
        goal: Prop = forced
    else:
        goal = _gen_goal(
            rng,
            atoms,
            settings.depth,
            leaf_p,
            repeat_bias=repeat_bias,
            and_w=and_w,
            or_w=or_w,
            imp_w=imp_w,
        )

    need = goal.atoms()
    for a in assumptions:
        need |= a.atoms()
    if not need.issubset(frozenset(atoms)):
        return None, "atom mismatch"

    stmt_prop = _build_statement(assumptions, goal)
    statement = stmt_prop.render()
    proof = _synthesize_proof(assumptions, goal, rng)
    if proof is None:
        return None, "proof synthesis failed"

    puzzle = Puzzle(
        statement=statement,
        proof=proof,
        settings={
            "num_vars": settings.num_vars,
            "depth": settings.depth,
            "seed": settings.seed,
            "statement_sha256_16": _statement_fingerprint(statement),
            "goal_kind": type(goal).__name__,
        },
    )
    return puzzle, None


def generate_puzzle(settings: GenerateSettings = GenerateSettings()) -> Puzzle:
    base_seed = settings.seed if settings.seed is not None else random.randrange(1 << 30)
    last_err: str | None = None
    attempts_cap = min(max(1, settings.max_attempts), 2048)
    for attempt in range(attempts_cap):
        rng = random.Random(base_seed + attempt * 100_003)
        puzzle, err = _try_generate_once(rng, settings)
        if puzzle is None:
            last_err = err
            continue
        return puzzle

    msg = f"generate_puzzle gave up after {attempts_cap} attempts"
    if last_err:
        msg += f" ({last_err})"
    raise RuntimeError(msg)
