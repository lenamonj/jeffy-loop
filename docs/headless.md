# How to run Jeffy fully autonomously

`/jeffy` is a slash command, but Claude Code can take one from the shell: `claude -p "/jeffy 10"` runs a full round headless and exits when the round ends. Every receipt from `ryu` onward was produced that way, unattended, with a shell loop supplying the rounds. Nothing in the engine changes; the loop cannot tell whether a person typed the command.

**Setup, once.**

1. Install Jeffy as in the [Quickstart](../README.md#quickstart) and sign in to Claude Code once interactively (`claude` then `/login`); the headless form reuses that session.
2. Clone the target and make sure the tree is clean and on a branch you are willing to see commits on. The loop checkpoints every iteration as a commit, and its pre-flight asks what to do about uncommitted work - a question a headless session never answers, so the round ends with nothing done.
3. Decide the budget before the first round and write it down: rounds and iterations per round. Below 10 iterations a round rarely reaches its own gate; narrow single-purpose libraries in the receipts converged in 10 to 20 iterations, wide surfaces (30+ inventory rows) took 40 or more.
4. Pass `--permission-mode bypassPermissions`. A headless session has nobody to answer a permission prompt, so without it the round stalls silently at the first tool call.

Two targets from the receipts, at the pins they were run at:

```bash
git clone https://github.com/dtolnay/itoa.git   ~/targets/itoa     # Rust,  converged in 2 rounds of 10
git clone https://github.com/ljharb/qs.git       ~/targets/qs       # JavaScript, 3 rounds of 10 declared
```

**Linux / macOS / WSL**

```bash
#!/usr/bin/env bash
# Run ROUNDS rounds of ITERS iterations against TARGET; stop early at convergence.
set -euo pipefail
TARGET=~/targets/itoa
ROUNDS=3
ITERS=10

cd "$TARGET"
for r in $(seq 1 "$ROUNDS"); do
  before=$(git rev-parse HEAD)
  claude -p "/jeffy $ITERS" --permission-mode bypassPermissions >> jeffy-run.log 2>&1
  # A round that made no checkpoint commit almost always hit a pre-flight
  # question nobody answered. Stop rather than burn the remaining rounds.
  [ "$before" != "$(git rev-parse HEAD)" ] || { echo "round $r: no progress, stopping"; exit 1; }
  grep -q '^Converged:' BACKLOG.md && { echo "converged in round $r"; exit 0; }
done
echo "budget spent: $ROUNDS rounds of $ITERS, not converged"
```

Two rounds of 15 instead: `ROUNDS=2 ITERS=15`. A single `/jeffy 10` is `ROUNDS=1`. To leave it running after you log out, put the script under `nohup`, `setsid -f`, or a `systemd-run --user` unit; the receipts used the last, with a memory ceiling so a runaway test binary cannot take the host with it.

**Windows PowerShell**

```powershell
# Run $Rounds rounds of $Iters iterations against $Target; stop early at convergence.
$Target = "$HOME\targets\itoa"
$Rounds = 3
$Iters  = 10

Set-Location $Target
for ($r = 1; $r -le $Rounds; $r++) {
    $before = git rev-parse HEAD
    claude -p "/jeffy $Iters" --permission-mode bypassPermissions 2>&1 | Add-Content jeffy-run.log
    if ($before -eq (git rev-parse HEAD)) { Write-Host "round $r: no progress, stopping"; exit 1 }
    if (Select-String -Path BACKLOG.md -Pattern '^Converged:' -Quiet) { Write-Host "converged in round $r"; exit 0 }
}
Write-Host "budget spent: $Rounds rounds of $Iters, not converged"
```

**What to read afterwards.** `JOURNAL.md` has one entry per iteration; `BACKLOG.md` ends with a `Converged:` line naming the commit if the run declared, and holds the open findings if it did not; `.jeffy/evaluator/` holds every gate verdict with the commands it ran. The log file is the raw session transcript and is only interesting when a round made no progress.

> [!NOTE]
> Rounds are separate sessions on purpose. Each new session re-reads the tree cold, which is what makes the second round's audit independent of the first round's beliefs. [Why that matters](usage.md#use-several-short-runs-not-one-long-one).

