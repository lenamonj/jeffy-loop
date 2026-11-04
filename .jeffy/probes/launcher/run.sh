#!/usr/bin/env bash
# Known-answer battery for the /jeffy launcher skill (skills/jeffy/SKILL.md).
#
# The skill is prose an agent executes, so most of it has no mechanical oracle.
# One part of it does, and it is the part this repository's own Lessons record
# as having broken twice: the launcher writes the loop state file and the Stop
# hook reads it, so the two files share a key contract that nothing checked.
# The Lesson reads "A mechanism this engine ships and its own repository does
# not use is untested where it matters most ... or the next run rediscovers the
# gap by being refused", marked [recurred]. A key the hook starts reading that
# the launcher never writes does not fail loudly - the reader returns empty and
# the feature silently takes its default, which is how `Verify summary pattern`
# shipped unread for a release.
#
# What is deliberately not re-asserted: the fenced bash blocks, which check 10
# parses; the verify-bound derivation chain, which check P rebuilds and
# compares; the truncator set and the sandbox answer set, which checks L and Q
# derive; and the flag set against docs/usage.md, which .jeffy/probes/docs
# compares. Restating any of those would give a single claim two sources rather
# than adding coverage.
#
# Expected: 22 checks, which is also what `grep -c '^ *ck "' run.sh` returns,
# no ck() sitting inside a loop here. The figure is worked out from the arms
# rather than read off a green run. It was first written as 20 and the run
# reported 19, which is the shape the Lesson about a silently dropped check
# warns of - so the static call sites were counted before the number was
# touched, they agreed with the run at 19, and the error was in the planning
# arithmetic rather than in the battery. A count that disagrees is explained
# before it is edited, never the other way round.
set -u
lc_root="${JEFFY_PROBE_ROOT:-$PWD}"
lc_skill="$lc_root/skills/jeffy/SKILL.md"
lc_hook="$lc_root/skills/jeffy/hooks/stop-hook.sh"
lc_ref="$lc_root/skills/jeffy/references"
for lc_f in "$lc_skill" "$lc_hook"; do
  [ -f "$lc_f" ] || { echo "launcher battery: no $lc_f"; exit 2; }
done
[ -d "$lc_ref" ] || { echo "launcher battery: no $lc_ref"; exit 2; }

lc_ok=0; lc_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then lc_ok=$((lc_ok + 1)); else
    lc_bad=$((lc_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

lc_tmp="$(mktemp -d)"
trap 'rm -rf "$lc_tmp"' EXIT

# --- 1. the pre-flight steps are a contiguous run ---------------------------
# A duplicated or skipped number is a step a launch reads past: the steps are
# referenced by number from the skill's own later text and from PLAN.md's
# inventory rows, so the numbering is a machine-read value rather than styling.
lc_nums="$(grep -oE '^[0-9]+\. ' "$lc_skill" | tr -d '. ' | tr '\n' ' ')"
ck "the pre-flight step count" 11 "$(printf '%s' "$lc_nums" | wc -w)"
ck "the pre-flight numbering is contiguous from 1" \
  "$(seq 1 "$(printf '%s' "$lc_nums" | wc -w)" | tr '\n' ' ')" "$lc_nums"

# --- 2. the state-key contract between the launcher and the hook ------------
# Three sets, each derived from the file that owns it. The hook's readers are
# its `fm <key>` calls; its writers are the literal `"<key>: ` emissions, with
# comment lines stripped first because a comment quoting the priced Declined
# reason `cost: exceeds one iteration` otherwise enters the write set and the
# partition passes for the wrong reason. The launcher's writers are the keys in
# the heredoc it writes the state file with, counting the three conditional
# lines whose keys sit inside an angle-bracket placeholder.
grep -ohE 'fm [a-z_]+' "$lc_hook" | awk '{print $2}' | sort -u > "$lc_tmp/reads"
sed 's/^[[:space:]]*#.*$//' "$lc_hook" | grep -ohE '"[a-z_]+: ' | tr -d '" :' | sort -u > "$lc_tmp/writes"
{ awk '/^cat > "\$PR\/\.claude\/jeffy-loop\.local\.md"/,/^EOF$/' "$lc_skill" | grep -oE '^<?[a-z_]+:' | tr -d '<:'
  awk '/^cat > "\$PR\/\.claude\/jeffy-loop\.local\.md"/,/^EOF$/' "$lc_skill" | grep -oE '^<[a-z_]+ ' | tr -d '< '
} | sort -u > "$lc_tmp/launch"
ck "the hook's reader set was extracted" 1 "$([ -s "$lc_tmp/reads" ] && echo 1 || echo 0)"
ck "the hook's writer set was extracted" 1 "$([ -s "$lc_tmp/writes" ] && echo 1 || echo 0)"
ck "the launcher's writer set was extracted" 1 "$([ -s "$lc_tmp/launch" ] && echo 1 || echo 0)"
# The contract: nothing the hook reads is unwritten. A key read but written by
# neither side is a feature running on its default with no way to notice.
sort -u "$lc_tmp/writes" "$lc_tmp/launch" > "$lc_tmp/written"
ck "every key the hook reads is written by the launcher or by the hook" "" \
  "$(comm -23 "$lc_tmp/reads" "$lc_tmp/written" | tr '\n' ' ' | sed 's/ $//')"
# The other direction is not empty and must not be asserted as empty: the
# launcher writes one key nothing reads, deliberately. `sandboxed` is the
# blast-radius disclosure for a human reading the state file, which BACKLOG.md
# states in F1's own reasoning, so it is named here rather than tolerated as
# slack - a second such key is a finding.
ck "the only launcher-written key nothing reads is the blast-radius disclosure" \
  "sandboxed" "$(comm -13 "$lc_tmp/reads" "$lc_tmp/launch" | tr '\n' ' ' | sed 's/ $//')"
ck "the hook really never reads that key" 0 "$(grep -c sandboxed "$lc_hook")"

# --- 3. the state file the launcher writes is readable by the hook's reader --
# The reader is taken out of the hook rather than retyped, because a second
# copy of a parser is the defect PLAN.md's Lesson about calling rather than
# re-typing a shared predicate already records. A state file is then built in
# the launcher's documented shape and every key read back through it.
lc_fm_def="$(grep -m1 '^fm() {' "$lc_hook")"
ck "the hook's frontmatter reader was extracted" 1 \
  "$([ -n "$lc_fm_def" ] && echo 1 || echo 0)"
state="$lc_tmp/state.md"
{
  echo "---"
  while IFS= read -r lc_k; do printf '%s: probe-value-%s\n' "$lc_k" "$lc_k"; done < "$lc_tmp/launch"
  echo "---"
  echo "Jeffy loop state."
} > "$state"
eval "$lc_fm_def"
lc_rt=""
while IFS= read -r lc_k; do
  [ "$(fm "$lc_k")" = "probe-value-$lc_k" ] || lc_rt="$lc_rt $lc_k"
done < "$lc_tmp/launch"
ck "every launcher-written key round-trips through the hook's own reader" "" "$lc_rt"

# --- 4. the templates the launcher copies are the shipped set ---------------
# The bootstrap block names each template by filename; the directory is what
# ships. A template named but absent breaks a launch on a fresh project, and
# one shipped but unnamed is never copied.
lc_named="$(grep -oE '[a-z-]+-(default|highs)\.md' "$lc_skill" | sort -u | tr '\n' ' ')"
lc_shipped="$(find "$lc_ref" -maxdepth 1 -type f -name '*-*.md' -printf '%f\n' | sort -u | tr '\n' ' ')"
ck "the launcher names a template set" 1 "$([ -n "$lc_named" ] && echo 1 || echo 0)"
ck "the templates the launcher names are the ones that ship" "$lc_shipped" "$lc_named"

# --- 5. the promise phrases agree with the prompts that must emit them ------
# The launcher writes completion_promise into the state file and the hook
# matches the model's output against it, so a phrase that disagrees with the
# prompt's own instruction makes a correct declaration unrecognisable.
ck "the standard promise the launcher writes is the one its prompt names" 1 \
  "$(grep -c 'JEFFY CONVERGED' "$lc_ref/iteration-prompt.txt")"
ck "the hunt promise the launcher writes is the one its prompt names" 1 \
  "$(grep -c 'JEFFY HUNT COMPLETE' "$lc_ref/iteration-prompt-highs.txt")"

# --- 6. the flag set and the values the launcher refuses outside ------------
lc_args="$lc_tmp/args"
awk '/^## Arguments$/ { f = 1; next } f && /^## / { exit } f' "$lc_skill" > "$lc_args"
# shellcheck disable=SC2016
# Literal markdown backticks delimit each flag in the skill's prose; they are
# not a command substitution.
ck "the launcher's flag set" "--highs --max-context --max-iter-time --max-surface --max-time --refeed " \
  "$(grep -ohE '`--[a-z][a-z-]+`' "$lc_args" | tr -d '`' | sort -u | tr '\n' ' ')"
# shellcheck disable=SC2016
ck "the two values --refeed accepts" "full pointer" \
  "$(grep -ohE '`(full|pointer)`' "$lc_args" | tr -d '`' | sort -u | tr '\n' ' ' | sed 's/ $//')"
# The mode guard reads the first word of PLAN.md's Mode section and refuses on
# a mismatch in either direction, so both words it compares must be present.
lc_modes=0
for lc_w in Improvement High-hunt; do
  grep -qF -- "$lc_w" "$lc_skill" && lc_modes=$((lc_modes + 1))
done
ck "both mode words the guard compares are named" 2 "$lc_modes"

# --- 7. every installed path the launcher runs exists -----------------------
# These are resolved at launch and executed. check 3 asserts a hand-written
# list of required paths; what is derived here is the set the skill itself
# names under hooks/, so a lib added to the launch sequence cannot be missed by
# a list nobody updated.
lc_libs="$(grep -ohE 'hooks/(lib/)?[a-z-]+\.sh' "$lc_skill" | sort -u)"
ck "the launcher names a hooks path set" 1 "$([ -n "$lc_libs" ] && echo 1 || echo 0)"
lc_missing=""
while IFS= read -r lc_l; do
  [ -n "$lc_l" ] || continue
  [ -f "$lc_root/skills/jeffy/$lc_l" ] || lc_missing="$lc_missing $lc_l"
done <<EOF
$lc_libs
EOF
ck "every hooks path the launcher names exists" "" "$lc_missing"

# --- the /cancel-jeffy skill, which is the other half of one contract --------
# Two skills and the hook share the loop state file: the launcher writes it,
# the hook reads it, and /cancel-jeffy deletes it. The third party had no
# instrument at all, and its failure mode is the quietest of the three - a
# cancel that names a path the launcher never writes reports no loop active and
# leaves the run going, which reads to a user exactly like a cancelled loop.
lc_cancel="$lc_root/skills/cancel-jeffy/SKILL.md"
if [ ! -f "$lc_cancel" ]; then
  echo "FAIL the /cancel-jeffy skill is missing at skills/cancel-jeffy/SKILL.md"
  lc_bad=$((lc_bad + 3))
else
  lc_cpaths="$(grep -ohE '\.claude/[a-z-]+\.local\.md(\.refused)?' "$lc_cancel" | sort -u | tr '\n' ' ')"
  lc_lpaths="$(grep -ohE '\.claude/[a-z-]+\.local\.md(\.refused)?' "$lc_skill" | sort -u | tr '\n' ' ')"
  ck "the launcher names a state-path set" 1 "$([ -n "$lc_lpaths" ] && echo 1 || echo 0)"
  # Compared as a set in both directions: a path /cancel-jeffy names and the
  # launcher never writes is a cancel that silently does nothing, and a path
  # the launcher writes and /cancel-jeffy never names is a file left behind
  # that re-feeds the next session.
  ck "/cancel-jeffy names exactly the state paths the launcher names" "$lc_lpaths" "$lc_cpaths"
  # Every frontmatter field it promises to report has to be a key the launcher
  # actually writes, or the report comes back blank.
  lc_cmiss=""
  for lc_f in session_id iteration started_at; do
    grep -qF -- "$lc_f" "$lc_cancel" || continue
    grep -qxF -- "$lc_f" "$lc_tmp/launch" || lc_cmiss="$lc_cmiss$lc_f "
  done
  ck "every frontmatter field /cancel-jeffy reports is a key the launcher writes" "" \
    "$(printf '%s' "$lc_cmiss" | sed 's/ *$//')"
fi

echo "  launcher: $((lc_ok + lc_bad)) checks, $lc_ok passed, $lc_bad failed"
if [ "$lc_bad" -eq 0 ]; then
  echo "launcher battery: $lc_ok/$((lc_ok + lc_bad)) checks passed"
  exit 0
fi
echo "launcher battery: $lc_ok/$((lc_ok + lc_bad)) checks passed, $lc_bad FAILED"
exit 1
