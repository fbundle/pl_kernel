
namespace EchoLine

universe u

private def Iter α := α → String → Option (α × String)

partial def main_loop (iter: Iter α) (state: α) (prompt?: Option (α → String) := none) : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let stderr ← IO.getStderr

  let prompt: α → String := match prompt? with
    | none => (λ _ => "")
    | some p => p

  stderr.putStr (prompt state)
  let line ← stdin.getLine
  if line.isEmpty then
    pure ()
  else
    match iter state line.trimAscii.toString with
      | none => pure ()
      | some (new_state, output) =>
        stdout.putStrLn output
        main_loop iter new_state prompt

end EchoLine
