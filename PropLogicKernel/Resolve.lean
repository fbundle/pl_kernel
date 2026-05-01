import PropLogicKernel.Basic
import PropLogicKernel.Print


-- resolveTacticToGoal?
-- apply tactic, return a new list of goals
-- and a new count variable
def resolveTacticToGoal? [Map α Nat P] (count: Nat) (g: G α) (t: T): Except String (Nat × List (G α)) :=
  -- get h? if specified
  let h?: Option P :=
    let hName?: Option Nat :=
      match t with
        | .apply hName => some hName
        | .exact hName => some hName
        | .cases hName => some hName
        | _ => none
    match hName? with
      | none => none
      | some hName => Map.get? g.hyp hName

  match (g.goal, t, h?) with
    -- if goal is A → B
    -- add assumption h: A and change goal to B
    | (.imp A B, .intro, _) =>
      Except.ok (count + 1, [{
        hyp := Map.set g.hyp count A,
        goal := B,
      }])

    -- if goal is B and h: A → B
    -- change to to A
    | (B, .apply _, some (.imp A1 B1)) =>
      if B == B1 then
        Except.ok (count, [{
          hyp := g.hyp,
          goal := A1,
        }])
      else
        Except.error s!"cannot apply {h?} into {B}"

    -- if goal is A and h: A
    -- done
    | (A, .exact _, some A1) =>

      if A == A1 then
        Except.ok (count, [])
      else
        Except.error s!"cannot exact {h?} into {A}"

    -- if goal is A ∧ B
    -- split into two goals A and B
    | (.and A B, .constructor, _) =>
      Except.ok (count, [
        {
          hyp := g.hyp,
          goal := A,
        },
        {
          hyp := g.hyp,
          goal := B,
        }
      ])

    -- if h: A ∨ B
    -- split into two subproblems (assume h₁: A) and (assume h₂: B)
    -- if h: A ∧ B
    -- add (h₁: A) and (h₂: B)
    -- if h: False
    -- done ex falso quodlibet (from False, anything follows)
    -- cases doesn't resolve implication
    | (_, .cases _, some (.or A B)) =>
      Except.ok (count + 2, [
        {
          hyp := (Map.set g.hyp count A),
          goal := g.goal,
        },
        {
          hyp := (Map.set g.hyp (count+1) B),
          goal := g.goal,
        },
      ])
    | (_, .cases _, some (.and A B)) =>
      Except.ok (count + 2, [{
        hyp := (Map.set (Map.set g.hyp count A) (count+1) B),
        goal := g.goal,
      }])
    | (_, .cases _, some (.fals)) =>
      Except.ok (count, [])

    -- if goal is A ∨ B
    -- change goal to A
    | (.or A B, .left, _) =>
      Except.ok (count, [{
        hyp := g.hyp,
        goal := A,
      }])
    -- if goal is A ∨ B
    -- change goal to B
    | (.or A B, .right, _) =>
      Except.ok (count, [{
        hyp := g.hyp,
        goal := B,
      }])
    | _ => Except.error s!"cannot resolve tactic {t}"

def resolveTactic? [Map α Nat P] (s: S α) (t: T): Except String (S α) :=
  match s.stack with
    | [] => Except.error "empty list of goals"
    | g :: remainingGoals =>
      match resolveTacticToGoal? s.count g t with
        | Except.error msg => Except.error msg
        | Except.ok (newCount, newGoals) => Except.ok { count := newCount, stack := newGoals ++ remainingGoals}

def resolveTacticMany? [Map α Nat P] (s: S α) (ts: List T): Except String (S α) :=
  match s.stack with
    | [] =>
      dbg_trace s!"\nno_more_goal\n"
      Except.ok s
    | g :: _ =>
      dbg_trace s!"\nhead_proof_state\n{g}"
      match ts with
        | [] =>
          Except.error "empty tactic"
        | t :: ts =>
          match resolveTactic? s t with
            | Except.error msg => Except.error msg
            | Except.ok s =>
              dbg_trace s!"resolved {t}\n"
              resolveTacticMany? s ts

def test : Unit → Nat :=
  let A := P.atom "A"
  let B := P.atom "B"

  let s := initState (emptyList: ListMap Nat P)
    (.imp (.and A B) (.and B A))

  let ts: List T := [
    T.intro,
    T.cases 0,
    T.constructor,
    T.exact 2,
    T.exact 1,
  ]


  let _ := match resolveTacticMany? s ts with
    | Except.error msg =>
      dbg_trace msg
      0
    | _ => 0

  (λ _ => 0)


-- #eval test
