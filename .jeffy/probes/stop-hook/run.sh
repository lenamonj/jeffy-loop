#!/usr/bin/env bash
# Known-answer battery for skills/jeffy/hooks/stop-hook.sh, the engine itself.
#
# It drives THIS TREE's hook - never the installed copy - with synthetic Stop
# payloads against a throwaway git project, and asserts the observable outcome
# of each case: the JSON decision, the state file's own mutation, the stderr
# diagnostic and the exit status. That distinction is the reason this battery
# exists rather than more hand probing: previous sweeps drove the installed
# hook while the row they recorded names the tree path, which was harmless
# only for as long as the two copies were byte-identical, and in a checkout
# that develops the engine they routinely are not.
#
# Usage: run.sh [tree-root]   (default: this repository)
# Exit 0 and one summary line when every known answer holds, 1 with the
# disagreements, 2 when the host cannot run the hook at all.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$(cd "$here/../../.." && pwd)}"
hook="$root/skills/jeffy/hooks/stop-hook.sh"

[ -r "$hook" ] || { echo "NOT RUNNABLE: no hook at $hook" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "NOT RUNNABLE: jq is absent and the hook cannot parse its input without it" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "NOT RUNNABLE: git is absent and every fixture here is a git work tree" >&2; exit 2; }

fails=0
ran=0
note() { fails=$((fails + 1)); echo "FAIL $1"; }
ok() { ran=$((ran + 1)); }
ck() { # $1 label, $2 got, $3 want
  ran=$((ran + 1))
  [ "$2" = "$3" ] || note "$1: got '$2', want '$3'"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
proj="$tmp/proj"
state="$proj/.claude/jeffy-loop.local.md"
mkdir -p "$proj/.claude"
printf 'iterate\n' > "$tmp/prompt.txt"

pg() { git -C "$proj" "$@"; }
pg init -q .
pg config user.email probe@example.invalid
pg config user.name probe
printf 'v1\n' > "$proj/product.txt"
mkdir -p "$proj/.jeffy/probes/core"
printf 'product.txt\n' > "$proj/.jeffy/probes/core/paths"
pg add -A >/dev/null 2>&1
pg commit -q -m seed
c1="$(pg rev-parse HEAD)"

write_state() { # $1 session, $2 iteration, $3 max
  {
    printf -- '---\n'
    printf 'session_id: %s\n' "$1"
    printf 'iteration: %s\n' "$2"
    printf 'max_iterations: %s\n' "$3"
    printf 'prompt_path: %s\n' "$tmp/prompt.txt"
    printf 'focus:\n'
    printf 'completion_promise: JEFFY CONVERGED\n'
    printf 'started_at: 2026-01-01T00:00:00Z\n'
    printf 'base_head: %s\n' "$c1"
    printf -- '---\n'
    printf 'Jeffy loop state.\n'
  } > "$state"
}

write_plan() { # $1... inventory rows
  {
    printf '# Plan\n\n## Verify command\nCommand: none\n\n## Surface inventory\n'
    for r in "$@"; do printf '%s\n' "$r"; done
  } > "$proj/PLAN.md"
}

write_backlog() { # $1 open-task line or empty, $2 Converged line or empty
  {
    printf '# Backlog\n\n## Now\n'
    [ -n "${1:-}" ] && printf '%s\n' "$1"
    printf '\n## Next\n\n## Later\n\n## Declined\n\n## Converged\n'
    [ -n "${2:-}" ] && printf '%s\n' "$2"
  } > "$proj/BACKLOG.md"
}

# The run id is the session id plus the HHMMSS of started_at, and the hook
# reads the closing entry by that id. A fixture journal headed with any other
# id makes every promise refuse for a reason that has nothing to do with the
# gate under test, which is how the first draft of this battery filed two
# failures against correct code.
write_journal() { # $1 session id
  {
    printf '## iter 1/3 | %s-000000 | 2026-01-01 | AUDIT | audit\n\nTask: the full fresh-evidence audit.\nVerification: zero High, zero Medium.\n\n' "$1"
    printf '## iter 2/3 | %s-000000 | 2026-01-01 | EVALUATOR | converged\n\nTask: the declaration.\nVerification: Evaluator: PASS - clean.\n' "$1"
  } > "$proj/JOURNAL.md"
}

# The gate reads the verdict from the artifact at the highest ordinal on
# record and requires it committed and unmodified, so a fixture that means to
# be accepted carries one.
write_artifact() { # $1 run id, $2 ordinal
  mkdir -p "$proj/.jeffy/evaluator"
  {
    printf '# Evaluator gate - run %s, invocation %s, iteration 2 of 3\n\n' "$1" "$2"
    printf 'Command: bash -c true\nExit: 0\n\n'
    printf 'Verdict: PASS\n'
  } > "$proj/.jeffy/evaluator/$1-$2.md"
  pg add .jeffy/evaluator >/dev/null 2>&1
  pg commit -q -m artifact
}

# Stdout goes to a file rather than through a command substitution, because a
# substitution runs the hook in a subshell and its exit status would never
# reach the assertions here - the same shape as reading a pipeline's status.
hook_rc=0
out=""
run_hook() { # $1 session, $2 last assistant message
  jq -n --arg s "$1" --arg m "$2" \
    '{session_id:$s,last_assistant_message:$m,transcript_path:"",hook_event_name:"Stop"}' > "$tmp/in.json"
  CLAUDE_PROJECT_DIR="$proj" bash "$hook" < "$tmp/in.json" >"$tmp/out" 2>"$tmp/err"
  hook_rc=$?
  out="$(cat "$tmp/out")"
}

reason() { printf '%s' "$1" | jq -r '.reason // ""' 2>/dev/null; }
decision() { printf '%s' "$1" | jq -r '.decision // ""' 2>/dev/null; }

write_plan "- [x] core: swept at $c1 via .jeffy/probes/core - probed every entry point"
write_backlog '' ''
write_journal sess-own
write_artifact sess-own-000000 1
c2="$(pg rev-parse HEAD)"

# ---- Row: fast paths and identity -------------------------------------------
rm -f "$state"
run_hook sess-1 'working'
ck "no state file is a silent no-op (exit)" "$hook_rc" "0"
ck "no state file is a silent no-op (stdout)" "$out" ""

write_state sess-own 1 3
before="$(cksum < "$state")"
run_hook sess-other 'working'
ck "a foreign session draws no decision" "$out" ""
ck "a foreign session leaves the state file byte-identical" "$(cksum < "$state")" "$before"

write_state sess-own 1 3
run_hook sess-own 'working'
ck "the owning session with budget left blocks" "$(decision "$out")" "block"
ck "the re-feed advances the counter" "$(grep -c '^iteration: 2$' "$state")" "1"

write_state sess-own notanumber 3
run_hook sess-own 'working'
ck "a non-numeric counter fails open rather than crashing" "$hook_rc" "0"

# ---- Row: re-feed path -------------------------------------------------------
# The hook reports the iteration the model is about to perform, not the one on
# disk, which is the semantics a hand-written probe got backwards once.
write_state sess-own 2 3
run_hook sess-own 'working'
ck "the run state names the iteration about to be performed" \
  "$(reason "$out" | grep -oE 'iteration 3 of 3' | head -n 1)" "iteration 3 of 3"

# Exhausting the budget has two answers and which one is correct depends on
# the ledger, so both are driven. With work still open the run simply ends;
# with nothing above Low left the hook grants the one-time +2 so the
# convergence sequence can finish. Asserting only the first reads as a defect
# against a hook doing exactly the right thing.
write_state sess-own 3 3
write_backlog '- [ ] X2 (Medium, engine): work still open. Acceptance: none.' ''
run_hook sess-own 'working'
ck "the budget boundary with work still open returns no decision" "$out" ""
ran=$((ran + 1))
[ -f "$state" ] && note "the budget boundary left the state file in place"

write_state sess-own 3 3
write_backlog '' ''
run_hook sess-own 'working'
ran=$((ran + 1))
reason "$out" | grep -qF 'CLOSING EXTENSION' \
  || note "the closing extension was withheld from a ledger with nothing above Low left"
ck "the closing extension re-feeds beyond the budget" \
  "$(reason "$out" | grep -oE 'iteration 4 of 5' | head -n 1)" "iteration 4 of 5"

# ---- Row: converged-stop gates ----------------------------------------------
write_state sess-own 1 3
mv "$proj/PLAN.md" "$tmp/PLAN.hidden"
run_hook sess-own 'done <promise>JEFFY CONVERGED</promise>'
ck "a promise over a project with no PLAN.md is refused" "$(decision "$out")" "block"
mv "$tmp/PLAN.hidden" "$proj/PLAN.md"

write_state sess-own 1 3
write_backlog '- [ ] X1 (Medium, engine): an open Medium. Acceptance: none.' "Converged: $c1 - 2026-01-01"
run_hook sess-own 'done <promise>JEFFY CONVERGED</promise>'
ran=$((ran + 1))
reason "$out" | grep -qF 'open High or Medium tasks' || note "the ledger severity floor did not refuse an open Medium"

write_state sess-own 1 3
write_backlog '' "Converged: $c1 - 2026-01-01"
write_plan "- [ ] uncovered: a surface nobody swept. Paths: product.txt." \
           "- [x] core: swept at $c1 via .jeffy/probes/core - probed every entry point"
run_hook sess-own 'done <promise>JEFFY CONVERGED</promise>'
ran=$((ran + 1))
reason "$out" | grep -qF 'still lists an unswept row' || note "the inventory gate did not refuse an unswept row"

write_state sess-own 1 3
write_backlog '' ''
write_plan "- [x] core: swept at $c1 via .jeffy/probes/core - probed every entry point"
run_hook sess-own 'done <promise>JEFFY CONVERGED</promise>'
ran=$((ran + 1))
reason "$out" | grep -qF 'does not name a commit' || note "the promise was accepted with no certifying Converged line"

# ---- V1: all four readers of the map agree that a placeholder is not a row ---
# The gate, the run-state count, the staleness scan and the stall digest each
# read the inventory, and the fix routes all four through one filter. The first
# two are directly observable here; the staleness scan speaks through the gate's
# own refusal, and the digest through the counter it is compared against.
ex_unswept='  - [ ] <surface>: <scope>. Paths: <space-separated paths>.'
ex_unreach='  - [~] <surface>: unreachable on this host - <reason>. Paths: <space-separated paths>.'
ex_swept='  - [x] <surface>: swept at <commit> via .jeffy/probes/<battery> - <what the sweep exercised>'

write_state sess-own 1 3
write_backlog '' "Converged: $c2 - 2026-01-01"
write_plan "- [x] core: swept at $c1 via .jeffy/probes/core - probed every entry point" \
           "$ex_unswept" "$ex_unreach" "$ex_swept"
run_hook sess-own 'done <promise>JEFFY CONVERGED</promise>'
ck "the gate accepts a map whose only extra rows are grammar examples" "$out" ""

write_state sess-own 1 3
run_hook sess-own 'working'
ck "the run state counts no grammar example as an unswept row" \
  "$(reason "$out" | grep -oE 'unswept rows [0-9]+' | head -n 1)" "unswept rows 0"

# The control: the fix keys on the placeholder, never on the indent, so an
# indented row naming a real surface is still a row to every reader.
write_state sess-own 1 3
write_plan "- [x] core: swept at $c1 via .jeffy/probes/core - probed every entry point" \
           "  - [ ] indented but real: a surface written with a leading space. Paths: product.txt."
run_hook sess-own 'working'
ck "the run state still counts an indented row naming a real surface" \
  "$(reason "$out" | grep -oE 'unswept rows [0-9]+' | head -n 1)" "unswept rows 1"

write_state sess-own 1 3
write_backlog '' "Converged: $c1 - 2026-01-01"
run_hook sess-own 'done <promise>JEFFY CONVERGED</promise>'
ran=$((ran + 1))
reason "$out" | grep -qF 'indented but real' || note "the gate stopped refusing an indented row naming a real surface"

if [ "$fails" -gt 0 ]; then
  echo "stop-hook battery: $((ran - fails))/$ran checks passed"
  exit 1
fi
echo "stop-hook battery: $ran/$ran checks passed"
