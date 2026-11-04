#!/usr/bin/env bash
# Known-answer battery for skills/jeffy/hooks/lib/quiet-verify.sh, in both of
# the roles that file has: sourced, where the hook calls its resolvers, and
# executed, where the loop runs it instead of the raw Verify command.
# shellcheck disable=SC2016  # every Command payload here is literal on
# purpose: the wrapper writes it into PLAN.md and `bash -c` expands it
# later, so a payload this script expanded would test the wrong string.
set -u
qvb_root="${JEFFY_PROBE_ROOT:-$PWD}"
qvb_sh="$qvb_root/skills/jeffy/hooks/lib/quiet-verify.sh"
[ -f "$qvb_sh" ] || { echo "quiet-verify battery: no $qvb_sh"; exit 2; }
qvb_ok=0; qvb_bad=0
ck() { if [ "$2" = "$3" ]; then qvb_ok=$((qvb_ok + 1)); else qvb_bad=$((qvb_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"; fi; }
ckin() { case "$3" in *"$2"*) qvb_ok=$((qvb_ok + 1)) ;; *) qvb_bad=$((qvb_bad + 1)); echo "FAIL $1: [$3] does not carry [$2]" ;; esac; }
t="$(mktemp -d)" || exit 2
trap 'rm -rf "$t"' EXIT

# A PLAN.md with the given Command payload and, unless told otherwise, the
# Oracle class line the wrapper requires before it runs anything.
plan() { # $1 dir, $2 command payload, $3.. extra labelled lines
  mkdir -p "$1"
  { printf '# Plan\n\n## Verify command\n'
    printf 'Command: %s\n' "$2"
    printf 'Oracle class: a fixture.\n'
    shift 2; for x in "$@"; do printf '%s\n' "$x"; done
  } > "$1/PLAN.md"
}
# Executed role. Captures stdout and stderr apart, because stdout being empty
# on green is the contract rather than a detail.
qv() { bash "$qvb_sh" "$1/PLAN.md" "${2:-$1}" >"$t/out" 2>"$t/err"; echo $?; }

# --- executed: each documented contract state, by its own shape -------------
plan "$t/none" none
ck "exit on Command: none" 0 "$(qv "$t/none")"
ckin "stderr on Command: none" "verify: not configured" "$(cat "$t/err")"

plan "$t/empty" ""
ck "exit on an empty Command" 2 "$(qv "$t/empty")"
ckin "stderr on an empty Command" "the Command line is empty" "$(cat "$t/err")"

plan "$t/ph" "<first audit fills this in>"
ck "exit on the template placeholder" 2 "$(qv "$t/ph")"
ckin "stderr on the template placeholder" "still the template placeholder" "$(cat "$t/err")"

# A2: a command merely carrying a redirect pair is not a placeholder. Anchored,
# this runs; unanchored it was refused at exit 2 every iteration.
plan "$t/redir" "true < /dev/null > /dev/null"
ck "exit on a command carrying a redirect pair" 0 "$(qv "$t/redir")"
ckin "a redirecting command runs rather than being called a placeholder" "verify: green" "$(cat "$t/err")"

mkdir -p "$t/nocmd"; printf '# Plan\n\n## Verify command\nOracle class: a fixture.\n' > "$t/nocmd/PLAN.md"
ck "exit on a section with no Command label" 2 "$(qv "$t/nocmd")"
ckin "stderr on a section with no Command label" "carries no Command: line" "$(cat "$t/err")"

mkdir -p "$t/noplan"
ck "exit with no PLAN.md" 2 "$(qv "$t/noplan")"
ckin "stderr with no PLAN.md" "verify: no PLAN.md at" "$(cat "$t/err")"

# Oracle class: absent with the fingerprint also absent fails open; present but
# empty is refused. Two values of one label that must change the answer.
mkdir -p "$t/preoracle"; printf '# Plan\n\n## Verify command\nCommand: true\n' > "$t/preoracle/PLAN.md"
ck "exit on a pre-1.8.0 PLAN.md with neither oracle nor fingerprint" 0 "$(qv "$t/preoracle")"
ckin "stderr names the pre-1.8.0 shape" "pre-1.8.0 shape" "$(cat "$t/err")"
mkdir -p "$t/emptyoracle"; printf '# Plan\n\n## Verify command\nCommand: true\nOracle class:\nEnvironment fingerprint: x\n' > "$t/emptyoracle/PLAN.md"
ck "exit on an empty Oracle class with a fingerprint present" 2 "$(qv "$t/emptyoracle")"
ckin "stderr on an empty Oracle class" "oracle class not declared" "$(cat "$t/err")"

# Green: silence on stdout is the feature.
plan "$t/green" "true"
ck "exit on a green command" 0 "$(qv "$t/green")"
ck "stdout is empty on green" "" "$(cat "$t/out")"
ckin "stderr on green names the oracle" "oracle=a fixture." "$(cat "$t/err")"

# The summary pattern: one labelled line that must change the green stderr.
plan "$t/summ" 'echo "7 passed in 0.1s"' 'Verify summary pattern: [0-9]+ passed'
ck "exit with a summary pattern" 0 "$(qv "$t/summ")"
ckin "green stderr carries the matched summary line" "7 passed in 0.1s" "$(cat "$t/err")"
ck "stdout is still empty with a summary pattern" "" "$(cat "$t/out")"
# and the count it records where the hook reads it
ck "verify-last.json records the first integer of the summary" 7 \
  "$(jq -r .count "$t/summ/.jeffy/metrics/verify-last.json" 2>/dev/null)"
# the same command with no pattern records nothing and says less
plan "$t/nosumm" 'echo "7 passed in 0.1s"'
ck "exit with no summary pattern" 0 "$(qv "$t/nosumm")"
qvb_vl=0; [ -f "$t/nosumm/.jeffy/metrics/verify-last.json" ] && qvb_vl=1
ck "no verify-last.json without a pattern" 0 "$qvb_vl"

# Failure: the exit status is the command's, and the output budget bounds the tail.
plan "$t/red" 'for i in 1 2 3 4 5 6; do echo "line$i"; done; exit 3' 'Verify output budget: 300'
ck "exit on a red command" 3 "$(qv "$t/red")"
ckin "stderr on red names the exit and the budget" "verify: FAILED (exit 3," "$(cat "$t/err")"
ck "tail at a budget of 300 carries every line" 6 "$(grep -c '^line[0-9]$' "$t/err")"
plan "$t/red2" 'for i in 1 2 3 4 5 6; do echo "line$i"; done; exit 3' 'Verify output budget: 2'
ck "exit on a red command at a budget of 2" 3 "$(qv "$t/red2")"
ck "tail at a budget of 2 carries two lines" 2 "$(grep -c '^line[0-9]$' "$t/err")"

# Timeout: the bound binds, and 124 is reported as a timeout rather than a failure.
plan "$t/slow" "sleep 30"
JEFFY_VERIFY_TIMEOUT_SECONDS=1 bash "$qvb_sh" "$t/slow/PLAN.md" "$t/slow" >"$t/out" 2>"$t/err"; qvb_trc=$?
ck "exit on a command past its bound" 124 "$qvb_trc"
ckin "stderr on a timeout names the bound" "verify: TIMEOUT after" "$(cat "$t/err")"

# --- sourced: the two resolvers the hook calls ------------------------------
# shellcheck source=/dev/null
. "$qvb_sh"
plan "$t/b100" "true" 'Verify duration: 100s'
plan "$t/b10"  "true" 'Verify duration: 10s'
plan "$t/bnone" "true"
ck "bound from an explicit state value" 300 "$(jeffy_verify_bound "$t/b100/PLAN.md" 300 2>/dev/null)"
ck "bound from a measured duration at 3x" 300 "$(jeffy_verify_bound "$t/b100/PLAN.md" '' 2>/dev/null)"
ck "bound floors a small measurement at 240" 240 "$(jeffy_verify_bound "$t/b10/PLAN.md" '' 2>/dev/null)"
ck "bound defaults to 240 with no measurement" 240 "$(jeffy_verify_bound "$t/bnone/PLAN.md" '' 2>/dev/null)"
ck "an explicit 0 is unset rather than no limit" 240 "$(jeffy_verify_bound "$t/bnone/PLAN.md" 0 2>/dev/null)"
ck "a leading zero is decimal rather than octal" 8 "$(jeffy_verify_bound "$t/bnone/PLAN.md" 08 2>/dev/null)"
ck "bound clamps to the cap the registration can honour" 1740 "$(jeffy_verify_bound "$t/bnone/PLAN.md" 2000 2>/dev/null)"
ckin "the clamp is said on stderr where it happens" "clamping to the cap" \
  "$(jeffy_verify_bound "$t/bnone/PLAN.md" 2000 2>&1 >/dev/null)"

# The pipefail predicate, at values that must disagree.
ck "an early closer behind a pipe turns pipefail off" "+o" "$(jeffy_verify_pipefail 'make test | grep -q ok')"
ck "a draining last stage keeps pipefail on" "-o" "$(jeffy_verify_pipefail 'make test | tee log')"
ck "an early closer after || is not one" "-o" "$(jeffy_verify_pipefail 'make test || grep -q ok log')"
ck "an early closer with no pipe before it is not one" "-o" "$(jeffy_verify_pipefail 'grep -q ok log; make test | tee log')"
ck "head behind a pipe turns pipefail off" "+o" "$(jeffy_verify_pipefail 'make test | head -5')"

# The labelled-line reader is scoped to its section, and the near-heading test
# quotes a writer's near miss without matching the section itself.
mkdir -p "$t/scope"
printf '# Plan\n\n## Lessons\nCommand: wrong\n\n## Verify command\nCommand: right\nOracle class: a fixture.\n' > "$t/scope/PLAN.md"
ck "the Command label is read inside its own section only" "right" "$(jeffy_plan_line "$t/scope/PLAN.md" 'Command')"
mkdir -p "$t/near"; printf '# Plan\n\n## Verify commands\nCommand: x\n' > "$t/near/PLAN.md"
ck "a near-miss heading is quoted back" "## Verify commands" "$(jeffy_near_heading "$t/near/PLAN.md" 'Verify command')"
ck "the real heading is no near miss" "" "$(jeffy_near_heading "$t/scope/PLAN.md" 'Verify command')"

# One wrapping backtick pair is stripped; two pairs are not, because re-pairing
# them would execute a command nobody wrote and it would still parse.
plan "$t/bt" '`true`'
ck "a single wrapping backtick pair is stripped" "true" "$(jeffy_plan_command "$t/bt/PLAN.md")"
plan "$t/bt2" '`a` && `b`'
ck "two backtick pairs are left alone" '`a` && `b`' "$(jeffy_plan_command "$t/bt2/PLAN.md")"

if [ "$qvb_bad" -eq 0 ]; then
  echo "quiet-verify battery: $qvb_ok/$qvb_ok checks passed"
  exit 0
fi
echo "quiet-verify battery: $qvb_bad of $((qvb_ok + qvb_bad)) checks failed"
exit 1
