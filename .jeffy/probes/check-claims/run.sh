#!/usr/bin/env bash
# Known-answer battery for skills/jeffy/hooks/lib/check-claims.sh.
# Every case pins an exact verdict line, the exact summary counts and the exit
# status. Liveness is not the test: this script exists to re-run a project's
# recorded measurements and say which no longer reproduce, so what has to be
# pinned is that a claim which stopped reproducing is reported and not merely
# survived.
set -u
CC="skills/jeffy/hooks/lib/check-claims.sh"
fails=0
cases=0
d="$(mktemp -d)"
mkdir -p "$d/.jeffy/probes/alpha" "$d/.jeffy/probes/beta"
o="$(mktemp)"; e="$(mktemp)"

ck() { # ck <label> <expected rc> <expected summary> <expected stdout, ; separated>
  local label="$1" want_rc="$2" want_sum="$3" want_out="$4"
  cases=$((cases + 1))
  bash "$CC" "$d" >"$o" 2>"$e"; local rc=$?
  local sum out
  sum="$(cat "$e")"; out="$(tr '\n' ';' < "$o")"
  if [ "$rc" != "$want_rc" ] || [ "$sum" != "$want_sum" ] || [ "$out" != "$want_out" ]; then
    echo "FAIL $label:"
    echo "  rc      want=$want_rc got=$rc"
    echo "  summary want=$want_sum got=$sum"
    echo "  stdout  want=$want_out got=$out"
    fails=$((fails + 1))
  fi
}

printf 'expect 7 :: echo 7\n' > "$d/.jeffy/probes/alpha/claims"
printf 'none\n' > "$d/.jeffy/probes/beta/claims"
ck "a claim that reproduces, beside a battery recording none" 0 \
   "claims: 1 checked, 0 mismatched, 0 errored, 0 skipped" "MATCH alpha: 7;"

# The case this instrument exists for: a recorded measurement that no longer
# reproduces is named with both values, never passed over.
printf 'expect 8 :: echo 7\n' > "$d/.jeffy/probes/alpha/claims"
ck "a claim that no longer reproduces" 1 \
   "claims: 1 checked, 1 mismatched, 0 errored, 0 skipped" "MISMATCH alpha: expected 8 got 7;"

# The comparison is the last non-empty line, trimmed - a command that prints
# working before its answer still compares as its answer.
printf 'expect 7 :: printf "a\\n7\\n\\n"\n' > "$d/.jeffy/probes/alpha/claims"
ck "the last non-empty line is what is compared" 0 \
   "claims: 1 checked, 0 mismatched, 0 errored, 0 skipped" "MATCH alpha: 7;"

printf 'expect 7 :: echo 7\nexpect 9 :: echo 9\n' > "$d/.jeffy/probes/alpha/claims"
ck "every line of a claims file is run, not the first" 0 \
   "claims: 2 checked, 0 mismatched, 0 errored, 0 skipped" "MATCH alpha: 7;MATCH alpha: 9;"

# A line that is not a claim is an error rather than a skip: a claims file
# whose syntax drifted must not read as a battery with nothing to check.
printf 'this is not a claims line\n' > "$d/.jeffy/probes/alpha/claims"
ck "a malformed line errors rather than skipping" 1 \
   "claims: 1 checked, 0 mismatched, 1 errored, 0 skipped" "ERROR alpha: malformed claims line 'this is not a claims line';"

printf 'expect 7 :: exit 4\n' > "$d/.jeffy/probes/alpha/claims"
ck "a command that fails errors with its status" 1 \
   "claims: 1 checked, 0 mismatched, 1 errored, 0 skipped" "ERROR alpha: exit 4 (exit 4);"

# AA2: a row this host cannot derive is skipped rather than checked, and the
# summary says how many. Counting a skip as checked made that one line - the
# line the declaration and the evaluator gate are both told to quote - read
# identically on a host that compared every row and on one that derived none.
# Both counters are pinned here, since only the pair distinguishes the hosts.
printf 'expect 7 :: echo 7\n' > "$d/.jeffy/probes/alpha/claims"
{
  printf '# Plan\n\n## Verify command\nCommand: none\n\n'
  printf "  done <<'COUNTS'\n"
  printf 'pdf-pages|32|echo unavailable:python3\n'
  printf 'skill-paths|8|echo 8\n'
  printf 'COUNTS\n'
} > "$d/PLAN.md"
ck "a row the host cannot derive is skipped and not checked, and the exit status is unaffected" 0 \
   "claims: 2 checked, 0 mismatched, 0 errored, 1 skipped" \
   "MATCH alpha: 7;SKIP PLAN:pdf-pages: unavailable:python3;MATCH PLAN:skill-paths: 8;"
rm -f "$d/PLAN.md"

# AD1: every row shape at once, which is the only case that can hold the two
# identities the output contract states - checked equals matched plus
# mismatched plus errored, and checked plus skipped is every row read. Neither
# was pinned before, because no case put an errored row beside a matched one
# and a skipped one, and the malformed shape was the one that broke both.
printf 'expect 7 :: echo 7\nexpect 8 :: echo 9\nexpect 5 :: exit 4\nnot a claims line\n' > "$d/.jeffy/probes/alpha/claims"
{
  printf '# Plan\n\n## Verify command\nCommand: none\n\n'
  printf "  done <<'COUNTS'\n"
  printf 'pdf-pages|32|echo unavailable:python3\n'
  printf 'COUNTS\n'
} > "$d/PLAN.md"
ck "every row shape at once, and both accounting identities hold" 1 \
   "claims: 4 checked, 1 mismatched, 2 errored, 1 skipped" \
   "MATCH alpha: 7;MISMATCH alpha: expected 8 got 9;ERROR alpha: exit 4 (exit 4);ERROR alpha: malformed claims line 'not a claims line';SKIP PLAN:pdf-pages: unavailable:python3;"
rm -f "$d/PLAN.md"

rm -f "$d/.jeffy/probes/alpha/claims" "$d/.jeffy/probes/beta/claims"
ck "batteries carrying no claims file check nothing" 0 \
   "claims: 0 checked, 0 mismatched, 0 errored, 0 skipped" ""

# Usage: an unusable root is refused at 2, distinct from the 1 that means a
# claim failed, so a caller can tell a broken invocation from a real finding.
bash "$CC" /no/such/directory >/dev/null 2>"$e"
if [ "$?" != 2 ]; then echo "FAIL an absent project root is refused at 2"; fails=$((fails + 1)); fi

rm -rf "$d" "$o" "$e"
[ "$fails" -eq 0 ] && echo "check-claims battery ok: $cases table-driven cases plus the usage case" || echo "check-claims battery: $fails failure(s)"
[ "$fails" -eq 0 ]
