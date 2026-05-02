
namespace EchoLine

def StateTransition α := α → String → (α × String × Bool)

partial def loop (t: StateTransition α) (state: α) (prompt: String) (alive: Bool): IO Unit := do
  if ¬ alive then
    pure ()
  else
    let stdin ← IO.getStdin
    let stdout ← IO.getStdout

    stdout.putStr prompt

    let line ← stdin.getLine
    if line.isEmpty then
      loop t state "" true  -- no op
    else
      let (newState, newPrompt, alive) := t state line
      loop t newState newPrompt alive

end EchoLine
