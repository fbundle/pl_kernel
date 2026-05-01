
namespace EchoLine

universe u

private def IterFunc α := α → String → α × String

partial def main_loop (iter: IterFunc α) (state: α) (init: String := "") : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  stdout.putStrLn init
  let line ← stdin.getLine
  if line.isEmpty then
    pure ()
  else
    let (new_state, output) := iter state line.trimAscii.toString
    stdout.putStrLn output
    main_loop iter new_state

end EchoLine
