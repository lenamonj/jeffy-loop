#!/usr/bin/env bash
# Known-answer battery for skills/jeffy/references - the iteration prompt the
# engine feeds at every turn end, its High-hunt sibling, and the three state
# file templates a launch copies into a target project.
#
# These are product the engine executes rather than prose about it: the hook
# reads the prompt from disk and re-feeds it verbatim, and the launcher's mode
# guard reads the first word of plan-default.md's Mode section. A template that
# loses a labelled line the hook parses makes the hook silently skip a
# converged-stop check, which PLAN.md's own Lessons record as having happened.
set -u
rf_root="${JEFFY_PROBE_ROOT:-$PWD}"
rf_d="$rf_root/skills/jeffy/references"
[ -d "$rf_d" ] || { echo "references battery: no $rf_d"; exit 2; }

rf_py=""
for rf_c in python3 python; do
  rf_py="$(command -v "$rf_c" 2>/dev/null)" && [ -n "$rf_py" ] && break
  rf_py=""
done
[ -n "$rf_py" ] || { echo "references battery: NOT RUNNABLE: no python3 or python on PATH; install python3"; exit 2; }

rf_ok=0; rf_bad=0
ck() { # $1 label, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then rf_ok=$((rf_ok + 1)); else
    rf_bad=$((rf_bad + 1)); echo "FAIL $1: expected [$2] got [$3]"
  fi
}

# --- 1. the shipped set is exactly the files a launch copies ------------------
# Derived from the directory rather than listed, and the count asserted, so a
# file added or removed reaches this battery instead of passing silently.
# find rather than ls, which shellcheck refuses at info level and this
# project's lint gate takes as a failure.
rf_files="$(find "$rf_d" -maxdepth 1 -type f -printf '%f\n' | sort | tr '\n' ' ')"
ck "the references set" \
  "backlog-default.md backlog-highs.md iteration-prompt-highs.txt iteration-prompt.txt journal-default.md plan-default.md plan-highs.md " \
  "$rf_files"

# --- 2. each prompt is a single line -----------------------------------------
# The hook JSON-encodes the prompt with jq and re-feeds it whole; a newline in
# it is the one shape that breaks the re-feed, and SKILL.md states the property.
for rf_p in iteration-prompt.txt iteration-prompt-highs.txt; do
  ck "$rf_p holds no newline" 0 "$(tr -dc '\n' < "$rf_d/$rf_p" | wc -c)"
  ck "$rf_p is non-empty" 1 "$([ -s "$rf_d/$rf_p" ] && echo 1 || echo 0)"
  ck "$rf_p carries no CR" 0 "$(tr -dc '\r' < "$rf_d/$rf_p" | wc -c)"
done

# --- 3. each prompt names its own promise phrase and only its own ------------
ck "the standard prompt names JEFFY CONVERGED" 1 "$(grep -c 'JEFFY CONVERGED' "$rf_d/iteration-prompt.txt")"
ck "the standard prompt does not name the hunt promise" 0 "$(grep -c 'JEFFY HUNT COMPLETE' "$rf_d/iteration-prompt.txt")"
ck "the hunt prompt names JEFFY HUNT COMPLETE" 1 "$(grep -c 'JEFFY HUNT COMPLETE' "$rf_d/iteration-prompt-highs.txt")"
ck "the hunt prompt does not name the convergence promise" 0 "$(grep -c 'JEFFY CONVERGED' "$rf_d/iteration-prompt-highs.txt")"

# --- 4. the mode word the launcher's guard reads ----------------------------
# SKILL.md refuses a launch by reading the first word of the Mode section body,
# so that word is a machine-read value and not prose.
rf_mode() { awk '/^## Mode$/ { getline; print $1; exit }' "$rf_d/$1"; }
ck "plan-default.md declares Improvement" "Improvement." "$(rf_mode plan-default.md)"
ck "plan-highs.md declares High-hunt" "High-hunt." "$(rf_mode plan-highs.md)"

# --- 5. the labelled lines the hook parses out of the plan template ---------
# Each is a line the engine reads by label. A template that drops one makes the
# hook skip the check that label feeds, with nothing going red.
for rf_lab in "## Verify command" "Command: " "Verify summary pattern:" "Verify output budget:" "Oracle class:" "Environment fingerprint:" "Verify duration:" "## Surface inventory" "## Definition of done" "## Lessons"; do
  ck "plan-default.md carries [$rf_lab]" 1 \
    "$([ "$(grep -cF -- "$rf_lab" "$rf_d/plan-default.md")" -ge 1 ] && echo 1 || echo 0)"
done
# The hunt template carries the same Verify machinery; it drops only the
# convergence half, so the Verify labels must survive into it.
for rf_lab in "## Verify command" "Command: " "Verify summary pattern:" "Oracle class:" "Environment fingerprint:"; do
  ck "plan-highs.md carries [$rf_lab]" 1 \
    "$([ "$(grep -cF -- "$rf_lab" "$rf_d/plan-highs.md")" -ge 1 ] && echo 1 || echo 0)"
done

# --- 6. the ledger sections the hook's section parser walks -----------------
rf_sect() { grep -cE "^## $2\$" "$rf_d/$1"; }
for rf_s in Now Next Later Proposed Declined Converged; do
  ck "backlog-default.md has one ## $rf_s" 1 "$(rf_sect backlog-default.md "$rf_s")"
done
for rf_s in Now Proposed Declined Hunted; do
  ck "backlog-highs.md has one ## $rf_s" 1 "$(rf_sect backlog-highs.md "$rf_s")"
done
# A hunt ledger carries no Converged history and no Medium queue; a standard
# ledger carries no Hunted. Both directions, because one alone would pass a
# template that carried every section.
ck "backlog-highs.md has no ## Converged" 0 "$(rf_sect backlog-highs.md Converged)"
ck "backlog-highs.md has no ## Next" 0 "$(rf_sect backlog-highs.md Next)"
ck "backlog-default.md has no ## Hunted" 0 "$(rf_sect backlog-default.md Hunted)"

# --- 7. the journal grammar the hook splits on ------------------------------
# The grammar line and its two enumerations are read as the template really
# writes them - angle-bracketed placeholders and a pipe-separated status set -
# rather than as the iteration prompt phrases the same rule. The first draft of
# these two arms searched for the prompt's wording and returned 0 for both,
# which reads exactly like a template that had lost its grammar.
ck "journal-default.md states the heading grammar" 1 \
  "$(grep -cF -- '## iter <i>/<N> | <run-id> |' "$rf_d/journal-default.md")"
rf_gram="$(grep -F -- '## iter <i>/<N> |' "$rf_d/journal-default.md" | head -n 1)"
ck "the grammar's ceremony keywords are enumerated" 1 \
  "$(printf '%s' "$rf_gram" | grep -c 'AUDIT or SWEEP or EVALUATOR or RATCHET or WRAPUP or SALVAGE or ROTATION')"
ck "the grammar's status vocabulary is enumerated" 1 \
  "$(printf '%s' "$rf_gram" | grep -c 'done|blocked|audit|converged|hunted|salvage|rotation')"
# The hunt's own closing status has to be in that vocabulary, since the hunt
# template's closing AUDIT entry takes it and journal-default.md is shared.
ck "the status vocabulary carries the hunt's closing status" 1 \
  "$(printf '%s' "$rf_gram" | grep -c 'hunted')"

# --- 8. the prompt pair's actual relationship, derived ----------------------
# skills/jeffy/SKILL.md says the hunt prompt is the standard prompt with the
# convergence machinery deleted "so every shared sentence stays byte-identical".
# That claim quantifies over a set and nothing in this tree derived it. This arm
# derives it: every hunt sentence is either byte-identical to a standard
# sentence, or it differs only by text the convergence machinery owns. The
# second case is the one the claim's wording denies, so the arm reports the
# partition rather than a yes or no.
rf_pair="$("$rf_py" - "$rf_d" <<'PY'
import pathlib, re, sys
d = pathlib.Path(sys.argv[1])
std = (d / "iteration-prompt.txt").read_text(encoding="utf-8").strip()
hi = (d / "iteration-prompt-highs.txt").read_text(encoding="utf-8").strip()
def sents(t):
    return [s.strip() for s in re.split(r'(?<=\.) (?=[A-Z])', t) if s.strip()]
S, H = sents(std), sents(hi)
if not S or not H:
    print("BROKEN: the sentence split returned nothing")
    raise SystemExit(0)
setS = set(S)
identical = [s for s in H if s in setS]
differing = [s for s in H if s not in setS]
# A differing sentence is accounted for when every token the convergence
# machinery owns is absent from it, or present in it as hunt vocabulary: the
# claim is that the hunt prompt removes that machinery, so a sentence that
# still carries it has not been derived by deletion at all.
CONV = ("JEFFY CONVERGED", "evaluator gate", "Evaluator gate", "EVALUATOR",
        "RATCHET", "Converged line", "convergence ratchet", "closing extension")
unaccounted = [s for s in differing if any(t in s for t in CONV)]
print("std=%d hunt=%d identical=%d differing=%d carrying-convergence=%d"
      % (len(S), len(H), len(identical), len(differing), len(unaccounted)))
for s in unaccounted[:3]:
    print("  CARRIES CONVERGENCE MACHINERY: %s" % s[:200])
PY
)"
ck "the prompt-pair split ran" 1 "$(printf '%s' "$rf_pair" | grep -c '^std=')"
# No hunt sentence may carry convergence machinery: that is the half of
# SKILL.md's claim which is true and which a drift would break.
ck "no hunt sentence carries convergence machinery" 0 \
  "$(printf '%s' "$rf_pair" | sed -n 's/.*carrying-convergence=\([0-9]*\).*/\1/p')"
# The byte-identical share is recorded as a measurement rather than asserted at
# a value, because deleting machinery inside a sentence necessarily reworks it
# and the number moves with every such edit. It is in this battery's claims
# file, which is where a measurement belongs.
echo "  prompt pair: $(printf '%s' "$rf_pair" | head -n 1)"

if [ "$rf_bad" -eq 0 ]; then
  echo "references battery: $rf_ok/$rf_ok checks passed"
  exit 0
fi
echo "references battery: $rf_bad of $((rf_ok + rf_bad)) checks failed"
exit 1
