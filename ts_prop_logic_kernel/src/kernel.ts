/**
 * Propositional Logic Types
 */
export type P =
  | { type: 'fals' }
  | { type: 'var'; name: string }
  | { type: 'and'; this: P; that: P }
  | { type: 'or'; this: P; that: P }
  | { type: 'imp'; this: P; that: P };

export const P = {
  fals: (): P => ({ type: 'fals' }),
  var: (name: string): P => ({ type: 'var', name }),
  and: (left: P, right: P): P => ({ type: 'and', this: left, that: right }),
  or: (left: P, right: P): P => ({ type: 'or', this: left, that: right }),
  imp: (left: P, right: P): P => ({ type: 'imp', this: left, that: right }),
};

export function equalsP(a: P, b: P): boolean {
  if (a.type !== b.type) return false;
  switch (a.type) {
    case 'fals': return true;
    case 'var': return a.name === (b as any).name;
    case 'and':
    case 'or':
    case 'imp':
      return equalsP(a.this, (b as any).this) && equalsP(a.that, (b as any).that);
  }
}

/**
 * Tactics
 */
export type T =
  | { type: 'intro' }
  | { type: 'exact'; n: number }
  | { type: 'apply'; n: number }
  | { type: 'compose'; n: number }
  | { type: 'constructor' }
  | { type: 'left' }
  | { type: 'right' }
  | { type: 'cases'; h: number }
  | { type: 'lem'; p: P };

export const T = {
  intro: (): T => ({ type: 'intro' }),
  exact: (n: number): T => ({ type: 'exact', n }),
  apply: (n: number): T => ({ type: 'apply', n }),
  compose: (n: number): T => ({ type: 'compose', n }),
  constructor: (): T => ({ type: 'constructor' }),
  left: (): T => ({ type: 'left' }),
  right: (): T => ({ type: 'right' }),
  cases: (h: number): T => ({ type: 'cases', h }),
  lem: (p: P): T => ({ type: 'lem', p }),
};

/**
 * Context (Mapping of index to Proposition)
 */
export type Ctx = Map<number, P>;

/**
 * Goal
 */
export interface G {
  hyp: Ctx;
  goal: P;
}

export function equalsG(a: G, b: G): boolean {
  if (!equalsP(a.goal, b.goal)) return false;
  if (a.hyp.size !== b.hyp.size) return false;
  for (const [k, v] of a.hyp) {
    const bv = b.hyp.get(k);
    if (!bv || !equalsP(v, bv)) return false;
  }
  return true;
}

/**
 * Proof State
 */
export interface S {
  varCount: number;
  sorrCount: number;
  newCount: number;
  stack: G[];
}

/**
 * Kernel Resolution Logic
 */
export function resolveGoal(t: T, vc: number, cl: boolean, g: G): { vc: number; goals: G[] } | null {
  const getHyp = (n: number): P | undefined => g.hyp.get(n);

  switch (t.type) {
    case 'intro':
      if (g.goal.type === 'imp') {
        const newHyp = new Map(g.hyp);
        newHyp.set(vc, g.goal.this);
        return { vc: vc + 1, goals: [{ hyp: newHyp, goal: g.goal.that }] };
      }
      break;

    case 'exact': {
      const h = getHyp(t.n);
      if (h && equalsP(g.goal, h)) {
        return { vc, goals: [] };
      }
      break;
    }

    case 'apply': {
      const h = getHyp(t.n);
      if (h && h.type === 'imp' && equalsP(g.goal, h.that)) {
        return { vc, goals: [{ hyp: g.hyp, goal: h.this }] };
      }
      break;
    }

    case 'compose': {
      const h = getHyp(t.n);
      if (h && h.type === 'imp') {
        return {
          vc,
          goals: [
            { hyp: g.hyp, goal: h.this },
            { hyp: g.hyp, goal: { type: 'imp', this: h.that, that: g.goal } },
          ],
        };
      }
      break;
    }

    case 'constructor':
      if (g.goal.type === 'and') {
        return {
          vc,
          goals: [
            { hyp: g.hyp, goal: g.goal.this },
            { hyp: g.hyp, goal: g.goal.that },
          ],
        };
      }
      break;

    case 'left':
      if (g.goal.type === 'or') {
        return { vc, goals: [{ hyp: g.hyp, goal: g.goal.this }] };
      }
      break;

    case 'right':
      if (g.goal.type === 'or') {
        return { vc, goals: [{ hyp: g.hyp, goal: g.goal.that }] };
      }
      break;

    case 'cases': {
      const h = getHyp(t.h);
      if (!h) break;
      if (h.type === 'or') {
        const hyp1 = new Map(g.hyp);
        hyp1.set(vc, h.this);
        const hyp2 = new Map(g.hyp);
        hyp2.set(vc + 1, h.that);
        return {
          vc: vc + 2,
          goals: [
            { hyp: hyp1, goal: g.goal },
            { hyp: hyp2, goal: g.goal },
          ],
        };
      }
      if (h.type === 'and') {
        const newHyp = new Map(g.hyp);
        newHyp.set(vc, h.this);
        newHyp.set(vc + 1, h.that);
        return { vc: vc + 2, goals: [{ hyp: newHyp, goal: g.goal }] };
      }
      if (h.type === 'fals') {
        return { vc, goals: [] };
      }
      break;
    }

    case 'lem':
      if (cl) {
        const newHyp = new Map(g.hyp);
        newHyp.set(vc, { type: 'or', this: { type: 'imp', this: t.p, that: { type: 'fals' } }, that: t.p });
        return { vc: vc + 1, goals: [{ hyp: newHyp, goal: g.goal }] };
      }
      break;
  }

  return null;
}

export function resolveState(t: T, cl: boolean, s: S): S | null {
  if (s.stack.length === 0) return null;
  const [g, ...gs] = s.stack;
  const res = resolveGoal(t, s.varCount, cl, g);
  if (!res) return null;
  return {
    ...s,
    varCount: res.vc,
    stack: [...res.goals, ...gs],
  };
}
