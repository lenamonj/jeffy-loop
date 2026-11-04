#!/usr/bin/env bash
# The executed half of the validate-sh battery: run the harness itself and
# assert what only a real run can establish.
#
# Why it is a separate script from run.sh. One invocation costs a full suite
# (minutes, not seconds), so putting these arms in run.sh would make the
# battery too slow to run per-iteration from its paths file, and putting them
# in claims would cost two full suites at every check-claims pass - which the
# gate runs at every declaration. So run.sh carries the static arms and this
# script carries the executed ones; a sweep of the row runs this and records
# its output on the inventory row. That bound is stated rather than silent.
#
# Usage: suite.sh                                    baseline arm
#        suite.sh <relpath> <old> <new> <expect>     mutated arm
#
# The stage is a detached git worktree at HEAD rather than a cp -a, because
# checks here read the git index (1b's exec bits), derive their file list from
# git ls-files (5's shellcheck set) and walk tracked artifacts (O), so a stage
# without .git would skip or fault for reasons no mutation caused. The baseline
# is re-run on the stage itself before any mutation verdict is read.
set -u
vs_root="${JEFFY_PROBE_ROOT:-$PWD}"
[ -f "$vs_root/scripts/validate.sh" ] || { echo "validate-sh suite: no $vs_root/scripts/validate.sh"; exit 2; }
command -v git >/dev/null 2>&1 ||
  { echo "validate-sh suite: NOT RUNNABLE: no git on PATH, and the stage is a git worktree; install git"; exit 2; }
git -C "$vs_root" rev-parse --verify HEAD >/dev/null 2>&1 ||
  { echo "validate-sh suite: NOT RUNNABLE: $vs_root is not a git checkout with a commit, so no worktree can be staged"; exit 2; }

vs_ok=0; vs_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then vs_ok=$((vs_ok + 1)); else
    vs_bad=$((vs_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

vs_tmp="$(mktemp -d)"
vs_wt="$vs_tmp/tree"
trap 'git -C "$vs_root" worktree remove --force "$vs_wt" >/dev/null 2>&1; rm -rf "$vs_tmp"' EXIT

git -C "$vs_root" worktree add --detach "$vs_wt" HEAD >/dev/null 2>&1 ||
  { echo "validate-sh suite: could not stage a worktree at $vs_wt"; exit 2; }

vs_label=baseline
if [ "$#" -ge 4 ]; then
  vs_label="mutated: $1"
  python3 "$vs_root/.jeffy/probes/validate-sh/mutate.py" "$vs_wt/$1" "$2" "$3" 1 >/dev/null ||
    { echo "validate-sh suite: the mutation did not land in $1, so its verdict would mean nothing"; exit 2; }
  # A staged shell file that no longer parses fails the suite for a reason the
  # mutation never caused, and that is indistinguishable from discrimination.
  case "$1" in
    *.sh) bash -n "$vs_wt/$1" 2>/dev/null ||
      { echo "validate-sh suite: the mutated $1 does not parse; the verdict would be about the mutation, not the check"; exit 2; } ;;
  esac
  cmp -s "$vs_root/$1" "$vs_wt/$1" &&
    { echo "validate-sh suite: the staged $1 is byte-identical to the shipped one; the mutation did not change the file"; exit 2; }
fi

( cd "$vs_wt" && bash scripts/validate.sh ) > "$vs_tmp/out.txt" 2> "$vs_tmp/err.txt"
vs_rc=$?

# The counters are the whole point of reading the output. pass(), fault() and
# skip() each print a line and bump a counter in the same breath, so a call
# that executed inside a command substitution or a pipeline subshell prints its
# line while its counter stays behind - the suite then reports fewer checks
# than it ran, or prints [FAIL] and exits 0. Comparing the printed population
# against the reported one tests that for all 500-odd sites in one observation,
# which no static read of the file can do.
vs_okn="$(grep -c '^\[OK\]' "$vs_tmp/out.txt")"
vs_skn="$(grep -c '^\[SKIP\]' "$vs_tmp/out.txt")"
vs_fln="$(grep -c '^\[FAIL\]' "$vs_tmp/out.txt")"
vs_sum="$(grep -E '^(All checks passed|Validation failed) \([0-9]+ ran, [0-9]+ skipped\)\.$' "$vs_tmp/out.txt" | tail -n 1)"
vs_ran="$(printf '%s' "$vs_sum" | sed -n 's/.*(\([0-9]*\) ran.*/\1/p')"
vs_skipped="$(printf '%s' "$vs_sum" | sed -n 's/.*ran, \([0-9]*\) skipped.*/\1/p')"

ck "$vs_label: the run prints exactly one summary line" 1 \
  "$(grep -cE '^(All checks passed|Validation failed) \([0-9]+ ran, [0-9]+ skipped\)\.$' "$vs_tmp/out.txt")"
ck "$vs_label: printed [OK] lines equal the reported ran count" "$vs_okn" "${vs_ran:-unparsed}"
ck "$vs_label: printed [SKIP] lines equal the reported skipped count" "$vs_skn" "${vs_skipped:-unparsed}"
# A population floor, because equality between two numbers both derived from an
# empty capture is satisfied by nothing having run at all.
ck "$vs_label: the run reported a plausible population (>=400 checks)" yes \
  "$([ "${vs_ran:-0}" -ge 400 ] 2>/dev/null && echo yes || echo "no (ran=${vs_ran:-unparsed})")"

if [ "$#" -ge 4 ]; then
  ck "$vs_label: the suite exits 1" 1 "$vs_rc"
  ck "$vs_label: at least one check faulted" yes "$([ "$vs_fln" -ge 1 ] && echo yes || echo no)"
  ck "$vs_label: the green summary is absent" 0 \
    "$(grep -c '^All checks passed' "$vs_tmp/out.txt")"
  ck "$vs_label: the expected check faulted" 1 \
    "$(grep -c -F -- "$4" "$vs_tmp/out.txt")"
  echo "  validate-sh suite: $vs_label -> rc=$vs_rc ok=$vs_okn skip=$vs_skn fail=$vs_fln; faults: $(grep '^\[FAIL\]' "$vs_tmp/out.txt" | sed 's/^\[FAIL\] //' | cut -c1-70 | tr '\n' '|')"
else
  ck "$vs_label: the suite exits 0" 0 "$vs_rc"
  ck "$vs_label: no check faulted" 0 "$vs_fln"
  ck "$vs_label: the summary is the green one" 1 \
    "$(grep -c '^All checks passed' "$vs_tmp/out.txt")"
  # The cross-file contract nothing else can check: PLAN.md's Verify summary
  # pattern is what the loop's wrapper greps the green line with, and PLAN.md
  # is gitignored here so no harness check can read it. A pattern that stops
  # matching does not fail loudly - the wrapper falls back to a shorter line
  # and every quoted count loses its source, which is this project's own
  # [recurred] Lesson.
  vs_pat="$(sed -n 's/^Verify summary pattern: //p' "$vs_root/PLAN.md" | head -n 1)"
  if [ -n "$vs_pat" ]; then
    ck "$vs_label: PLAN.md's Verify summary pattern matches the line the harness prints" 1 \
      "$(printf '%s\n' "$vs_sum" | grep -cE "$vs_pat")"
  else
    echo "  validate-sh suite: PLAN.md states no Verify summary pattern, so the wrapper's reader is unchecked"
    vs_bad=$((vs_bad + 1))
  fi
  # The harness grades a tree; it must not write to it. A check that leaves a
  # modified file behind would be swept into the next checkpoint by git add -A.
  ck "$vs_label: the graded tree is left clean" "" \
    "$(git -C "$vs_wt" status --porcelain | head -n 3 | tr '\n' ' ' | sed 's/ *$//')"
  echo "  validate-sh suite: $vs_label -> rc=$vs_rc ran=$vs_ran skipped=$vs_skipped; skips: $(grep '^\[SKIP\]' "$vs_tmp/out.txt" | sed 's/^\[SKIP\] //' | tr '\n' '|')"
fi

if [ "$vs_bad" -eq 0 ]; then
  echo "validate-sh suite: $vs_ok/$((vs_ok + vs_bad)) checks passed"
  exit 0
fi
echo "validate-sh suite: $vs_ok/$((vs_ok + vs_bad)) checks passed, $vs_bad FAILED"
exit 1
