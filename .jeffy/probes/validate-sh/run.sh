#!/usr/bin/env bash
# Invariant battery for scripts/validate.sh - the harness every other claim in
# this repository rests on, and the one file in the tree that nothing grades.
#
# What it is for. The Verify command is the oracle: the Surface inventory, the
# Derived and settled sections and every journal entry's quoted count all stand
# on "All checks passed". That sentence is a claim about the harness, and a
# green run can never falsify a claim about what the harness cannot see. So the
# arms here are invariants over the harness's own shape - the shapes in which a
# check stops being able to go red, or reports a pass it never counted, or
# leaves state behind - rather than a re-derivation of what the checks assert.
#
# The split between this file and suite.sh is cost, and it is stated rather
# than silent: an executed arm costs a full suite run, so the arms that need
# one live in suite.sh, which a sweep of this row runs and records. Nothing
# here runs the harness.
#
# Expected: 34 executed checks. `grep -c '^ *ck "' run.sh` returns 34 and no
# ck() sits inside a loop or a command substitution, so the static count and
# the executed count agree on every host that has a PLAN.md stating a Verify
# summary pattern; where that line is absent two of the 34 are replaced by one
# FAIL worth two, which is the only shape in which the totals differ. A
# disagreement is explained before it is edited.
set -u
vs_root="${JEFFY_PROBE_ROOT:-$PWD}"
vs_v="$vs_root/scripts/validate.sh"
[ -f "$vs_v" ] || { echo "validate-sh battery: no $vs_v"; exit 2; }

vs_ok=0; vs_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then vs_ok=$((vs_ok + 1)); else
    vs_bad=$((vs_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

vs_tmp="$(mktemp -d)"
trap 'rm -rf "$vs_tmp"' EXIT

# --- the check-region partition ---------------------------------------------
# A check is a comment block opening with its own id - `# 1.`, `# 6b3.`, `# K4.`,
# `# L/M.` - and the id grammar alone over-matches: a wrapped comment whose
# sentence happens to break at a word followed by a period reads identically
# (`# counts. Its two markers ...`, `# passed. Second and third, ...`). The
# discriminator is positional rather than lexical: a header opens a block, so
# the line before it is not a comment. Both halves are reported, because the
# rule is only worth anything if it rejects something.
vs_part() { # $1 file -> "header pass=<n> fault=<n>" per accepted region
  awk '
    prev !~ /^#/ && /^# [0-9A-Za-z][0-9A-Za-z\/]*\. / {
      h = $0; sub(/^# /, "", h); sub(/\..*/, "", h); cur = h; order[++n] = cur; prev = $0; next }
    { body[cur] = body[cur] "\n" $0; prev = $0 }
    END {
      for (i = 1; i <= n; i++) {
        c = order[i]; b = body[c]
        printf "%s pass=%d fault=%d\n", c, gsub(/(^|[^a-z_])pass "/, "&", b), gsub(/(^|[^a-z_])fault "/, "&", b)
      }
    }' "$1"
}
vs_part "$vs_v" > "$vs_tmp/regions.txt"
vs_loose="$(grep -cE '^# [0-9A-Za-z][0-9A-Za-z/]*\. ' "$vs_v")"
vs_acc="$(grep -c . "$vs_tmp/regions.txt")"

ck "the header grammar matches a plausible population (>=40 candidates)" yes \
  "$([ "$vs_loose" -ge 40 ] && echo yes || echo "no ($vs_loose)")"
ck "the accepted regions are a plausible population (>=35)" yes \
  "$([ "$vs_acc" -ge 35 ] && echo yes || echo "no ($vs_acc)")"
# A rule that rejects nothing is a rule nobody needed, and one that rejects
# everything reads exactly like one that found everything.
ck "the block-opening rule rejects at least one id-shaped continuation line" yes \
  "$([ "$vs_loose" -gt "$vs_acc" ] && echo yes || echo "no (loose=$vs_loose accepted=$vs_acc)")"

# Proved on a known positive and a known negative before its silence counts.
printf 'code\n# 7. A real header.\n#    continuation text.\n# counts. A sentence that broke here.\nmore code\n' > "$vs_tmp/fix.sh"
ck "the rule accepts a block-opening header and rejects a wrapped continuation" "7" \
  "$(vs_part "$vs_tmp/fix.sh" | awk '{print $1}' | tr '\n' ' ' | sed 's/ *$//')"

# Partition completeness: every reporting site falls inside exactly one region.
# Without this the arms below are about whatever the partition happened to see.
vs_gp="$(grep -cE '(^|[^a-z_])pass "' "$vs_v")"
vs_gf="$(grep -cE '(^|[^a-z_])fault "' "$vs_v")"
ck "the harness reports from a plausible number of sites (>=400 pass, >=400 fault)" yes \
  "$([ "$vs_gp" -ge 400 ] && [ "$vs_gf" -ge 400 ] && echo yes || echo "no (pass=$vs_gp fault=$vs_gf)")"
ck "every pass site falls inside an accepted region" "$vs_gp" \
  "$(awk '{gsub(/pass=/,"",$2); s+=$2} END {print s+0}' "$vs_tmp/regions.txt")"
ck "every fault site falls inside an accepted region" "$vs_gf" \
  "$(awk '{gsub(/fault=/,"",$3); s+=$3} END {print s+0}' "$vs_tmp/regions.txt")"

# A check with no fault site can never go red, and one with no pass site never
# reports the health it establishes. Both directions, because a region is
# allowed to be neither only as a shared preamble, which is named rather than
# tolerated as slack.
ck "no region can pass but not fault" "" \
  "$(awk '$2 != "pass=0" && $3 == "fault=0" {print $1}' "$vs_tmp/regions.txt" | tr '\n' ' ' | sed 's/ *$//')"
ck "no region can fault but not pass" "" \
  "$(awk '$3 != "fault=0" && $2 == "pass=0" {print $1}' "$vs_tmp/regions.txt" | tr '\n' ' ' | sed 's/ *$//')"
ck "the only region that reports nothing is the shared L/M preamble" "L/M" \
  "$(awk '$2 == "pass=0" && $3 == "fault=0" {print $1}' "$vs_tmp/regions.txt" | tr '\n' ' ' | sed 's/ *$//')"

# --- the counters ------------------------------------------------------------
# pass(), fault() and skip() each print a line and move a counter together, and
# the summary is computed from the counters alone. Anything else that assigns
# one of them can report health the run did not have: a check that clears
# `fail` hides every earlier failure, and one that bumps `ok_n` publishes a
# pass nobody printed. The writing sites are therefore exactly two each - the
# initialisation and the helper - which is a property of the file rather than
# of any check in it.
# Occurrences rather than lines: grep -c counts matching lines, so a third
# writer appended to a line that already assigns the counter would be invisible
# to the arm written to catch exactly that.
vs_writes() { grep -oE "(^|[^a-z_])$1=" "$vs_v" | grep -c .; }
ck "fail is assigned at exactly two sites" 2 "$(vs_writes fail)"
ck "ok_n is assigned at exactly two sites" 2 "$(vs_writes ok_n)"
ck "skip_n is assigned at exactly two sites" 2 "$(vs_writes skip_n)"
ck "skipped is assigned at exactly two sites" 2 "$(vs_writes skipped)"
ck "fault() is the writer of fail" 1 "$(grep -c '^fault() {.*fail=1' "$vs_v")"
ck "pass() is the writer of ok_n" 1 "$(grep -c '^pass() {.*ok_n=' "$vs_v")"
ck "skip() is the writer of skip_n and skipped" 1 "$(grep -c '^skip() {.*skip_n=.*skipped=' "$vs_v")"

# -e would abort the run at the first non-zero command, and many checks test a
# command's status on purpose; -u and pipefail are the deliberate pair.
ck "the harness runs under -u and pipefail" 1 "$(grep -c '^set -uo pipefail$' "$vs_v")"
ck "the harness does not run under -e" 0 "$(grep -cE '^set -[a-z]*e' "$vs_v")"

# --- the summary line --------------------------------------------------------
# Three readers: a human, the exit status, and the loop's verify wrapper, which
# greps this line with the pattern PLAN.md states. PLAN.md is gitignored here,
# so no harness check can read it, and a pattern that stops matching does not
# fail loudly - the wrapper falls back to a shorter line and every count a
# journal entry quotes loses its source. That is this project's own [recurred]
# Lesson about a mechanism the engine ships and nothing here declares.
# shellcheck disable=SC2016  # the patterns below are source text, not expansions
ck "the green summary names both counters and exits 0" 1 \
  "$(grep -A2 '^if \[ "\$fail" -eq 0 \]; then$' "$vs_v" | grep -c '^  echo "All checks passed (\$ok_n ran, \$skip_n skipped)\."$')"
# shellcheck disable=SC2016  # the patterns below are source text, not expansions
ck "the green summary is followed by exit 0" 1 \
  "$(grep -A3 '^if \[ "\$fail" -eq 0 \]; then$' "$vs_v" | grep -c '^  exit 0$')"
# shellcheck disable=SC2016  # the patterns below are source text, not expansions
ck "the red summary names both counters" 1 \
  "$(grep -c '^echo "Validation failed (\$ok_n ran, \$skip_n skipped)\."$' "$vs_v")"
# shellcheck disable=SC2016  # the patterns below are source text, not expansions
ck "the red summary is followed by exit 1" 1 \
  "$(grep -A1 '^echo "Validation failed (\$ok_n ran, \$skip_n skipped)\."$' "$vs_v" | grep -c '^exit 1$')"

# The green line is taken out of the harness and rendered, never retyped here:
# a literal written beside the pattern would compare the pattern against this
# battery's idea of the line, so a renamed green line would leave both green.
vs_green="$(awk '/^if \[ "\$fail" -eq 0 \]; then$/ { g = 1; next } g && /^  echo "/ { sub(/^  echo "/, ""); sub(/"$/, ""); print; exit }' "$vs_v")"
# shellcheck disable=SC2016  # the patterns below are source text, not expansions
vs_rendered="$(printf '%s\n' "$vs_green" | sed 's/\$ok_n/123/; s/\$skip_n/4/')"
vs_pat="$(sed -n 's/^Verify summary pattern: //p' "$vs_root/PLAN.md" 2>/dev/null | head -n 1)"
ck "the green line is extractable from the harness" yes \
  "$([ -n "$vs_green" ] && echo yes || echo no)"
if [ -n "$vs_pat" ]; then
  ck "PLAN.md's Verify summary pattern matches the green line the harness renders" 1 \
    "$(printf '%s\n' "$vs_rendered" | grep -cE "$vs_pat")"
  ck "that pattern does not match a renamed green line" 0 \
    "$(printf 'Every check passed (123 ran, 4 skipped).\n' | grep -cE "$vs_pat")"
else
  echo "FAIL PLAN.md states no Verify summary pattern, so the wrapper's reader of this line is underived"
  vs_bad=$((vs_bad + 2))
fi

# --- the skips ---------------------------------------------------------------
# A skip is the honest record of surface this host cannot reach, and PLAN.md's
# Environment fingerprint derives its gate list from these call sites. Two
# properties make that derivation possible: each one says why, and none of them
# is unconditional - a top-level skip silences a check on every host.
ck "the skip population is plausible (>=20 sites)" yes \
  "$([ "$(grep -cE '^ +skip "' "$vs_v")" -ge 20 ] && echo yes || echo "no ($(grep -cE '^ +skip "' "$vs_v"))")"
ck "every skip states its reason in a parenthetical" "" \
  "$(grep -nE '^ +skip "' "$vs_v" | grep -v '(' | tr '\n' ' ' | sed 's/ *$//')"
ck "no skip is unconditional at the top level" 0 "$(grep -cE '^skip "' "$vs_v")"

# --- temp hygiene ------------------------------------------------------------
# The harness builds its sandboxes with mktemp -d, and the trap at the head of
# the file exists so an aborted run does not leak them. Three sets decide
# whether that holds: the directories created, the ones the trap covers, and
# the ones removed on the normal path. The partition below is pinned as it
# stands, and two of its three arms are labelled `known gap:` because the state
# they pin is wrong rather than intended - filed on the ledger, not hidden
# here. A fix turns those two red in the same iteration, deliberately.
# shellcheck disable=SC2016  # the patterns below are source text, not expansions
vs_mk="$(grep -oE '^[[:space:]]*[a-z_0-9]+="\$\(mktemp -d' "$vs_v" | sed 's/^[[:space:]]*//; s/="\$(mktemp -d$//' | sort -u)"
vs_trapv="$(grep -m1 '^trap ' "$vs_v" | grep -oE '\$\{[a-z_0-9]+:\+' | sed 's/^\${//; s/:+$//' | sort -u)"
vs_rmv="$(grep -oE 'rm -rf "\$[a-z_0-9]+"' "$vs_v" | sed 's/^rm -rf "\$//; s/"$//' | sort -u)"
printf '%s\n' "$vs_mk" | grep . > "$vs_tmp/mk"
printf '%s\n' "$vs_trapv" | grep . > "$vs_tmp/trap"
printf '%s\n' "$vs_rmv" | grep . > "$vs_tmp/rm"
sort -u "$vs_tmp/trap" "$vs_tmp/rm" > "$vs_tmp/cleaned"

ck "the sandbox population is plausible (>=10 mktemp -d variables)" yes \
  "$([ "$(grep -c . "$vs_tmp/mk")" -ge 10 ] && echo yes || echo "no ($(grep -c . "$vs_tmp/mk"))")"
ck "the EXIT trap names at least one sandbox variable" yes \
  "$([ "$(grep -c . "$vs_tmp/trap")" -ge 1 ] && echo yes || echo no)"
ck "known gap: the sandboxes no path ever removes (J12)" "rv_tmp" \
  "$(comm -23 "$vs_tmp/mk" "$vs_tmp/cleaned" | tr '\n' ' ' | sed 's/ *$//')"
ck "known gap: the sandboxes removed only on the normal path, outside the trap (J12)" \
  "cc_tmp hu_tmp qv_tmp ri_tmp s_tmp so_tmp u_tmp" \
  "$(comm -12 "$vs_tmp/mk" "$vs_tmp/rm" | comm -23 - "$vs_tmp/trap" | tr '\n' ' ' | sed 's/ *$//')"
ck "the sandboxes the trap covers" "hb_tmp k4_tmp pr_tmp rt_tmp v_tmp" \
  "$(comm -12 "$vs_tmp/mk" "$vs_tmp/trap" | tr '\n' ' ' | sed 's/ *$//')"

echo "  validate-sh: regions=$vs_acc (of $vs_loose candidates) pass-sites=$vs_gp fault-sites=$vs_gf sandboxes=$(grep -c . "$vs_tmp/mk") trapped=$(grep -c . "$vs_tmp/trap")"
if [ "$vs_bad" -eq 0 ]; then
  echo "validate-sh battery: $vs_ok/$((vs_ok + vs_bad)) checks passed"
  exit 0
fi
echo "validate-sh battery: $vs_ok/$((vs_ok + vs_bad)) checks passed, $vs_bad FAILED"
exit 1
