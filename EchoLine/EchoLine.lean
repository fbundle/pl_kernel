
namespace EchoLine

def StateTransition α := α → String → (α × String)

partial def loop (t: StateTransition α) (state: α) (prompt: String) : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout

  stdout.putStr prompt

  let line ← stdin.getLine
  if line.isEmpty then
    loop t state ""  -- no op
  else
    let (newState, newPrompt) := t state line
    loop t newState newPrompt

end EchoLine
