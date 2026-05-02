
namespace REPL

structure Output α where
  state: α
  err: List String
  out: List String

abbrev Transition α := α → String → Output α

partial def run (trans: Transition α) (prev: Output α)
  (errPrefix: String := "-- ")
  (outPrefix: String := "")
  (prompt: String := "> ")
: IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let stderr ← IO.getStderr

  let err := String.intercalate "" (prev.err.map (λ line => errPrefix ++ line ++ "\n"))
  let out := String.intercalate "" (prev.out.map (λ line => outPrefix ++ line ++ "\n"))

  stderr.putStr err
  stdout.putStr out

  stderr.putStr prompt
  let line ← stdin.getLine
  let current := trans prev.state line
  run trans current errPrefix outPrefix prompt

end REPL
