#!/usr/bin/env bash
# Jeffy Stop hook: the loop engine. Registered machine-wide in
# ~/.claude/settings.json by the installer and fired at every
# turn end of every session, so the no-state fast path comes first and stays
# silent. While .claude/jeffy-loop.local.md at the project root names this
# session and budget remains, the hook re-feeds the iteration prompt by
# blocking the stop; it deletes the state file and lets the session end when
# the budget is spent or the completion promise appears in the last assistant
# message. Anchored to CLAUDE_PROJECT_DIR, which hooks receive fixed at the
# directory Claude Code was started in, so Bash-tool cwd drift mid-iteration
# cannot kill the loop.
set -u
JEFFY_VERSION="1.15.0"

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  root="$(pwd)"
fi
state="$root/.claude/jeffy-loop.local.md"
[ -f "$state" ] || exit 0

# The verify bound and the runner are shared with lib/quiet-verify.sh, which
# the loop invokes per iteration, so the engine holds exactly one timeout
# ladder rather than two that can drift apart. Resolved from this script's
# own location: the installer copies hooks/ whole, and $0 is where it landed.
# Absence is recorded, not fatal here - the converged stop turns it into a
# refusal, which is where failing closed belongs. (P1-50)
# Loop memory, enumerated once. Three things ask "did anything outside the
# loop's own bookkeeping move": the converged-tree check, the stall gate, and
# (from 1.13.0) the oscillation hash. They were two copies of one regex and
# adding a third was the moment to stop: two definitions of one signal is one
# too many, and when they drift the gates disagree about what progress is
# while both look right in isolation. (P1-19's lesson, P1-48's application.)
JEFFY_LOOP_MEMORY_RE='^(PLAN\.md|BACKLOG\.md|JOURNAL\.md|JOURNAL-archive\.md|\.jeffy/.*|\.claude/jeffy-loop\.local\.md|\.claude/settings\.local\.json)$'

# A digest of the tracked tree with loop memory excluded, so a run that
# reverts its own work returns to a hash it already had. The plain tree hash
# cannot do this: every iteration writes a journal entry, so the plain hash
# always differs and an oscillating run looks like a progressing one forever.
jeffy_content_tree_hash() { # $1 project root
  git -C "$1" ls-tree -r HEAD 2>/dev/null | awk -F'\t' -v re="$JEFFY_LOOP_MEMORY_RE" '
    NF == 2 && $2 !~ re { print $1 "\t" $2 }
  ' | cksum | tr ' \t' '--'
}

# The primary journal type of one iteration of this run - the task id or the
# ceremony keyword in the heading's fourth column - last match wins, ROTATION
# and SALVAGE skipped, exactly as the stall gate reads it. Defined once because
# three readers need it: the P0-5 sample filter (P0-7), the oscillation
# fingerprint, and the stall exemption. Prints nothing without a run token,
# because without started_at the run id is the bare session prefix every run
# of the session shares.
jeffy_iter_type() { # $1 journal path, $2 run token "| <runid8> |", $3 iteration
  [ -f "$1" ] || return 0
  awk -v tok="$2" -v it="$3" '
    { sub(/\r$/, "") }
    /^## iter / && index($0, tok) {
      split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (t == "ROTATION" || t == "SALVAGE") next
      n = f[1]; sub(/^## iter[ \t]*/, "", n); sub(/\/.*/, "", n)
      if (n + 0 == it + 0) type = t
    }
    END { print type }
  ' "$1"
}

qv_lib="${BASH_SOURCE[0]%/*}/lib/quiet-verify.sh"
if [ -f "$qv_lib" ]; then
  # shellcheck source-path=SCRIPTDIR
  # shellcheck source=lib/quiet-verify.sh
  . "$qv_lib"
else
  qv_lib=""
fi

# jq is a declared prerequisite; without it the hook cannot parse its stdin,
# so fail open (allow the stop) and say why, rather than trap the session.
if ! command -v jq >/dev/null 2>&1; then
  echo "jeffy stop hook: jq not found on PATH; not re-feeding. Install jq and re-run /jeffy." >&2
  exit 0
fi

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"

# Frontmatter fields are fixed single-line keys written by the /jeffy launch;
# the state file body never starts a line with any of them.
fm() { sed -n "s/^$1: //p" "$state" | head -n 1; }
fm_session="$(fm session_id)"
iter="$(fm iteration)"
max="$(fm max_iterations)"
prompt_path="$(fm prompt_path)"
focus="$(fm focus)"
promise="$(fm completion_promise)"

# Foreign or orphaned state file: another session owns it. Leave it alone;
# /jeffy pre-flight is the place that adjudicates orphans with the user.
if [ -z "$fm_session" ] || [ "$fm_session" != "$session_id" ]; then
  exit 0
fi

# Each field is validated on its own: the concatenation read "" + "10" as a
# well-formed "10", and a state file missing its iteration line re-fed
# forever because the rewriter never found a line to advance (P2-30).
case "${iter:-x}${max:-x}" in
  *[!0-9]*)
    echo "jeffy stop hook: malformed state file $state (iteration=$iter, max_iterations=$max); not re-feeding. Run /cancel-jeffy or delete the file." >&2
    exit 0
    ;;
esac

# Run identity: the session prefix alone does not name a run. Relaunching
# /jeffy in the same Claude Code session reuses the session id, so several
# runs stamp identical headings and the journal cannot say where one ended -
# observed across six runs and 64 iterations on one project. The started_at
# time from the loop state, which is rewritten at every launch, separates
# them. A state file without it predates this and falls back to the prefix.
# Derived here rather than at the re-feed because the declaration's evaluator
# check reads the journal under the same run id the hygiene checks use, and
# two derivations of one identity drift.
runid8="${fm_session:0:8}"
run_tok="$(printf '%s' "$(fm started_at)" | sed -n 's/.*T\([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\).*/\1\2\3/p')"
if [ -n "$run_tok" ]; then
  runid8="$runid8-$run_tok"
fi

# P2-21: one telemetry record per turn end. JOURNAL.md is prose - greppable,
# which is enough for one run and useless across fifty - so the numbers this
# hook already computes are also written as JSON: iterations to convergence,
# rows swept per run, verify time, evaluator invocations, strike counts.
#
# It lives under .jeffy/metrics/ and is COMMITTED, which is the opposite of
# where run exhaust usually goes and follows from this tree's own model:
# .jeffy/ is loop memory, the checkpoints commit all of it on purpose, and
# only the transient state file is ignored. It also lands inside a path the
# loop-memory exclusion list already covers, so a metrics write can never
# register as progress in the stall gate or the oscillation hash - the
# alternative would have been telemetry that manufactures the very signal it
# exists to measure.
#
# P2-29: this used to sit at the foot of the file, after every branch that
# ends a run had already exited, so the only turn it never recorded was the
# one that mattered - three targets came up four records short across four
# runs each, every gap the closing turn. It is a function on an EXIT trap
# now, installed the moment the run identity is known, so the record does
# not depend on which branch ends the turn. Every field defaults, because
# the early exits fire long before the fingerprint and sweep numbers exist
# and `set -u` inside a trap would abort the hook rather than the write.
jeffy_metrics_written=0
# shellcheck disable=SC2317  # reached through the EXIT trap installed below
jeffy_write_metrics() {
  [ "$jeffy_metrics_written" = 0 ] || return 0
  jeffy_metrics_written=1
  [ -n "$run_tok" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  metrics_dir="$root/.jeffy/metrics"
  mkdir -p "$metrics_dir" 2>/dev/null || return 0
  jq -n -c \
    --arg run "$runid8" --argjson iter "${iter:-0}" --argjson budget "${max:-0}" \
    --arg task "${fp_task:-}" --arg tree "${fp_hash:-}" \
    --argjson changed "${fp_changed:-0}" \
    --arg rows_unswept "${unswept_rows:-}" \
    --arg open_hm "${open_hm:-}" --argjson gate "${ev_art_ord:-0}" \
    --argjson stall "${new_stall:-0}" --argjson osc "${new_osc:-0}" \
    --argjson overrun "${new_overrun:-0}" \
    --arg wall "${wall_elapsed:-}" --arg ctx "${ctx_growth:-}" \
    '{run_token: $run, iteration: $iter, budget: $budget, task: $task,
      content_tree_hash: $tree, changed_paths: $changed,
      rows_unswept: (if $rows_unswept == "" then null else ($rows_unswept | tonumber) end),
      open_above_low: (if $open_hm == "" then null else ($open_hm | tonumber) end),
      evaluator_invocations: $gate, stall_strike: $stall,
      oscillation_strike: $osc, overrun_strike: $overrun,
      wall_elapsed_s: (if $wall == "" then null else ($wall | tonumber) end),
      context_growth: (if $ctx == "" then null else (($ctx | tonumber) / 10) end),
      cost_estimate_usd: null}' >> "$metrics_dir/$runid8.jsonl" 2>/dev/null || true
}
trap jeffy_write_metrics EXIT

# Invocations this run has already spent, derived once because two places
# need it: the declaration's absolute-bound refusal and the closing
# extension, which has nothing left to buy for a run that can no longer
# produce a verdict. Counted inside this run's own primary entries rather
# than by a file-wide grep, which would count other runs and rotated prose,
# and at most once per entry, because an entry may quote the word twice.
# The artifact ordinal is the second reading of the same quantity: the gate
# writes one path per invocation, so the highest ordinal on record is the
# number of invocations that actually left evidence.
ev_rejects=0
if [ -f "$root/JOURNAL.md" ]; then
  # Only EVALUATOR entries are counted, and this is the whole of the
  # correctness here. An ordinary task entry names the rejection that filed
  # its task - "G1, filed by the gate at iteration 5 under Evaluator: REJECT"
  # is exactly the provenance the prompt asks a run to record - so a scan over
  # every primary entry read those references as verdicts. A run one rejection
  # into a cap-3 budget counted three and was refused as past every cap: a
  # false refusal of a legal convergence, on the precise path P1-3 opened, and
  # worse than the fail-open it replaced because it broke runs that had done
  # everything right. Only an EVALUATOR entry carries a verdict.
  # It undercounts rather than overcounts where a single EVALUATOR entry
  # records two verdicts, and that is the safe direction on purpose: this is
  # an absolute backstop, the prompt owns the cap, and the artifact ordinal
  # is the second reading of the same quantity. skip starts at 1 so a
  # preamble line before the first heading is never counted.
  ev_rejects="$(awk -v tok="| $runid8 |" '
    BEGIN { skip = 1 }
    { sub(/\r$/, "") }
    /^## iter / {
      split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (index($0, tok) && t == "EVALUATOR") { skip = 0; counted = 0 } else { skip = 1 }
      next
    }
    !skip && !counted && index($0, "Evaluator: REJECT") { n++; counted = 1 }
    END { print n + 0 }
  ' "$root/JOURNAL.md")"
  case "$ev_rejects" in '' | *[!0-9]*) ev_rejects=0 ;; esac
fi
# The ordinal is parsed off the full "$runid8-" prefix rather than the last
# hyphen, because the run id carries a hyphen of its own (session prefix,
# then the started_at HHMMSS token).
# Written as a plain loop keeping the running maximum, never as a command
# substitution wrapping this case statement. Stock macOS ships bash 3.2,
# whose parser scans $( ... ) for the closing paren and takes the one that
# ends a case pattern instead, so the whole hook died with "syntax error near
# unexpected token `newline`" on that platform - every gate dead, on the one
# host the project promises the same bounded check as any other. It parsed
# fine under Git Bash and bash 5, which is exactly why the CI leg exists.
ev_art_ord=""
for ev_cand in "$root/.jeffy/evaluator/$runid8"-*.md; do
  [ -f "$ev_cand" ] || continue
  ev_n="${ev_cand##*/}"; ev_n="${ev_n#"$runid8-"}"; ev_n="${ev_n%.md}"
  case "$ev_n" in '' | *[!0-9]*) continue ;; esac
  if [ -z "$ev_art_ord" ] || [ "$ev_n" -gt "$ev_art_ord" ]; then
    ev_art_ord="$ev_n"
  fi
done

# Extension honesty, first half: the +2 window buys the convergence sequence
# and never an audit. A full audit run inside the window manufactures the
# clean-audit precondition the declaration cites, and every other gate here
# is blind to it - the ledger stays empty, the rows stay swept, the verdict
# reads PASS. Observed twice before this check existed: python-dotenv run 3,
# then the TOML-M receipt, whose iteration-13 audit its declaration cited.
# The window is the last two iterations of the extended budget, so an AUDIT
# primary entry for this run numbered max-1 or higher ends the run out of
# budget on the spot - before any promise below can be read - and
# convergence falls to the next run's fresh audit, which is what the
# prompt's "never run an audit inside it" always meant. The second half of
# the honesty pair, the ledger-refill check, lives below the promise path.
# No token, no scan: on a state file with no started_at the run id is the
# bare session prefix every run of the session shares, and a PRIOR run's
# audit at a high iteration would end THIS run out of budget - the same
# bound the ceremony exemption and the duplicate-index check carry.
if [ "$(fm extension_granted)" = "1" ] && [ -n "$run_tok" ] && [ -f "$root/JOURNAL.md" ]; then
  ext_max="$(fm max_iterations)"
  case "$ext_max" in ''|*[!0-9]*) ext_max="" ;; esac
  if [ -n "$ext_max" ]; then
    ext_audit="$(awk -v tok="| $runid8 |" -v lo=$((ext_max - 1)) '
      { sub(/\r$/, "") }
      /^## iter / && index($0, tok) {
        split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
        n = f[1]; sub(/^## iter[ \t]*/, "", n); sub(/\/.*/, "", n)
        if (t == "AUDIT" && n + 0 >= lo) { print n + 0; exit }
      }
    ' "$root/JOURNAL.md")"
    if [ -n "$ext_audit" ]; then
      echo "jeffy stop hook: an AUDIT entry sits at iteration $ext_audit, inside the closing extension window; the extension buys the convergence sequence and never an audit, so a clean audit produced there is not a precondition a declaration may cite. Ending the run out of budget; convergence falls to the next run's fresh audit." >&2
      rm -f "$state"
      exit 0
    fi
  fi
fi

# Completion promise: prefer the last_assistant_message field newer CLIs put
# on stdin; fall back to the last assistant entry of the JSONL transcript.
violation=""
# Set by the converged-hash check below, read by the two evaluator checks that
# date their evidence against it. Declared here because a non-git project
# never reaches that branch and set -u would take the difference personally.
conv_hash=""
if [ -n "$promise" ]; then
  last="$(printf '%s' "$input" | jq -r '.last_assistant_message // empty')"
  if [ -z "$last" ]; then
    transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
    if [ -n "$transcript" ] && [ -f "$transcript" ]; then
      last="$(jq -rRs 'split("\n") | map(fromjson? // empty) | map(select(.type == "assistant")) | (last // empty) | [.message.content[]? | select(.type == "text") | .text] | join("\n")' "$transcript" 2>/dev/null || true)"
    fi
  fi
  case "$last" in
    *"<promise>"*"$promise"*"</promise>"*)
      # Machine-checked converged stop: the promise alone does not end the
      # run; the closing claims must verify. A missing ledger is an
      # infrastructure defect and fails open; a discipline violation falls
      # through to the re-feed below with the evidence appended.
      # A missing ledger was the broadest fail-open left in this hook, and it
      # sat in front of every gate rather than beside one. A missing PLAN.md
      # costs exactly one check and the note says so; a missing BACKLOG.md
      # cost all of them - the open-task test, the Converged hash that
      # certifies the tree, and both gates 1.7.0 added read that file, and the
      # promise was accepted before any of them ran. It was the one shape
      # where the machine-checked stop was not checked at all, and deleting
      # one file was the whole price. Closed the way the journal fail-opens
      # were closed in 1.7.0, and as a violation rather than an end, so a
      # ledger lost to a bad rotation is repairable inside the budget.
      # P0-2 (1.9.0): the closing test is a severity floor, not an empty
      # ledger. An open High or Medium blocks; an open Low is carried - named
      # on the accept path's stderr note so the run report cannot silently
      # omit it. Severity is read from the task line's mandated form
      # `- [ ] <ID> (<Severity>, ...)`, and the parse FAILS CLOSED: a line
      # carrying no parseable severity blocks, because a floor that guesses
      # is a floor that gets gamed by omission. [b] and [~] lines are not
      # open tasks and are untouched, exactly as before.
      open_blocking=""
      open_carried=""
      if [ -f "$root/BACKLOG.md" ]; then
        open_scan="$(awk '{ sub(/\r$/, "") } /^## (Now|Next|Later)$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ { if ($0 ~ /^- \[ \] [^ ]+ \(Low[,)]/) print "L\t" $0; else print "B\t" $0 }' "$root/BACKLOG.md")"
        open_blocking="$(printf '%s\n' "$open_scan" | awk -F'\t' '$1 == "B" { print $2 }')"
        open_carried="$(printf '%s\n' "$open_scan" | awk -F'\t' '$1 == "L" { print $2 }')"
      fi
      if [ ! -f "$root/BACKLOG.md" ]; then
        violation="BACKLOG.md is missing at $root, and every convergence gate reads it - the open-task test, the Converged hash that certifies the tree, and the ratchet all live in that file; restore the ledger with its Now, Next, Later, and Converged sections, then re-declare"
      elif [ -n "$open_blocking" ]; then
        violation="BACKLOG.md still lists open High or Medium tasks in Now, Next, or Later (a task line with no parseable severity counts as blocking - the closing rule reads severity from the task line itself), first: $(printf '%s' "$open_blocking" | head -n 1)"
      elif command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
        # Converged-hash check: the latest Converged line must name a commit
        # in this repository, and nothing but loop state may have changed
        # between it and HEAD - the ratchet's definition of an unchanged
        # tree. HEAD-exact equality would be unsatisfiable wherever the state
        # files are tracked, because the closing checkpoint commits the
        # Converged line itself. Skipped in non-git projects. The line is
        # markdown a model writes, so a leading list marker and backticks
        # around the hash are tolerated; the section anchoring is not.
        # The repoint suffix is read off the same line, so one pass yields
        # both hashes: "<new> <old>" when the line carries the marker, the
        # new hash alone when it does not.
        conv_pair="$(awk '{ sub(/\r$/, "") } /^## Converged$/ { take = 1; next } /^## / { take = 0 } take && /^[-*] +Converged: / { sub(/^[-*] +/, "") } take && /^Converged: / { h = $2; gsub(/^`|`$/, "", h); o = ""; if (match($0, /\(repoints [^,)]+/)) { o = substr($0, RSTART + 10, RLENGTH - 10); gsub(/^`|`$|^[ \t]+|[ \t]+$/, "", o) } } END { if (h) print h " " o }' "$root/BACKLOG.md")"
        conv_hash="${conv_pair%% *}"
        conv_old="${conv_pair#* }"
        [ "$conv_old" = "$conv_pair" ] && conv_old=""
        if [ -z "$conv_hash" ] || ! git -C "$root" rev-parse --verify --quiet "$conv_hash^{commit}" >/dev/null 2>&1; then
          violation="the ## Converged section of BACKLOG.md does not name a commit in this repository; append the Converged line for the certified checkpoint"
        else
          # Reachability first, because an orphaned hash makes the
          # nothing-but-state comparison below meaningless: git will happily
          # diff two commits with no ancestry between them and report a
          # difference that means nothing about this run's work.
          # Reachability. Through 1.7.0 the hash only had to rev-parse to a
          # commit object, and any commit object satisfies that: an orphan
          # left by a rebase, an abandoned branch tip, a commit fetched from
          # somewhere else. A published receipt whose Converged hash does not
          # resolve on a clone is one nobody can verify, which is the single
          # claim this corpus is least able to defend.
          # The first production tree to meet this went the honest way and
          # still had to break a rule to do it. 63 checkpoints were squashed
          # before publication, the certified commit went unreachable, and
          # because the artifact and ratchet checks both date their evidence
          # with merge-base against that hash, the only way to keep the tree
          # legal was to edit a line the template declares un-editable. The
          # engine offered no legal path, so the operator took an
          # illegal-looking one and disclosed it. That is fixed here: the
          # append below is the legal path, and the disclosure travels with
          # the receipt instead of resting on the operator's goodwill.
          # What stays unenforceable, stated rather than papered over: a
          # tree-preserving edit that repoints at a reachable commit without
          # the marker is indistinguishable from an original line at the
          # content layer. This does not detect that. What it changes is that
          # the honest operator now has a legal move, so an edit no longer
          # has an excuse.
          if [ -z "$violation" ] && [ -n "$conv_old" ]; then
            if ! git -C "$root" rev-parse --verify --quiet "$conv_old^{commit}" >/dev/null 2>&1; then
              violation="the Converged line repoints $conv_old, which no longer resolves to a commit in this repository, so the tree it certified cannot be compared against $conv_hash and the repoint cannot be checked; a repoint is only ever legal against a commit whose tree can still be read, so converge this tree again through a fresh audit and the gate rather than asserting the old one"
            elif ! printf '%s\n' "$(awk '{ sub(/\r$/, "") } /^## Converged$/ { take = 1; next } /^## / { take = 0 } take && /^[-*] +Converged: / { sub(/^[-*] +/, "") } take && /^Converged: / { h = $2; gsub(/^`|`$/, "", h); a[++n] = h } END { for (i = 1; i < n; i++) print a[i] }' "$root/BACKLOG.md")" \
              | grep -qix -- "$conv_old"; then
              violation="the Converged line repoints $conv_old but no earlier Converged line in BACKLOG.md names it; a repoint is appended beneath the line it supersedes and never written over it, because the superseded line is the only evidence that the rewrite happened at all"
            elif [ "$(git -C "$root" rev-parse --verify --quiet "$conv_old^{tree}" 2>/dev/null)" \
              != "$(git -C "$root" rev-parse --verify --quiet "$conv_hash^{tree}" 2>/dev/null)" ]; then
              violation="the Converged line repoints $conv_old to $conv_hash, but those two commits do not carry the same tree; a repoint answers a history rewrite that preserved the tree, and one that changes it is a different convergence claim wearing an old certificate, so converge the current tree through a fresh audit and the gate"
            fi
          fi
          if [ -z "$violation" ] \
            && ! git -C "$root" merge-base --is-ancestor "$conv_hash" HEAD 2>/dev/null; then
            violation="the Converged hash $conv_hash resolves but is not reachable from HEAD, so a history rewrite has orphaned the commit this convergence rests on and no clone of this repository can check it; never edit the Converged line - append one beneath it reading Converged: <new hash> - <date> (repoints $conv_hash, tree unchanged), naming a reachable commit whose tree equals the orphaned one, and record the rewrite in a dated Note in JOURNAL.md"
          fi
          # .jeffy/ is loop memory too, so it joins the state files in the
          # exclusion: a row's known-answer battery lives under
          # .jeffy/probes/ and the checkpoints commit it, which makes a
          # battery written or refreshed on the way to the declaration
          # loop-state churn rather than a product change. Without this the
          # run that kept its instruments fails the nothing-but-state test
          # that the run which threw them away and rebuilt them passes, and
          # the persistence the probes exist for costs a declaration.
          # Two files under .claude/ are named for the same reason and no
          # more of that directory than those two, because a Claude Code
          # plugin project has real product there. jeffy-loop.local.md is
          # this hook's own transient state, gitignored at bootstrap but
          # tracked wherever that step did not run, and it changes at every
          # turn; settings.local.json is written by the harness whenever the
          # run's work draws a permission grant. Neither is the project.
          # --relative is what makes any of this hold in a project that is a
          # subdirectory of a larger repository - a shape the launch
          # pre-flight explicitly permits - because git reports paths from
          # the repository root and every filename here is anchored at the
          # project root, so without it the exclusion matched nothing and the
          # gate rejected every declaration it saw.
          if [ -z "$violation" ]; then
            nonstate="$(git -C "$root" diff --name-only --relative "$conv_hash" HEAD 2>/dev/null | grep -vE "$JEFFY_LOOP_MEMORY_RE" | head -n 1)"
            if [ -n "$nonstate" ]; then
              violation="product path $nonstate changed after the Converged hash $conv_hash; certify the current tree before declaring"
            fi
          fi
        fi
      fi
      # Surface-inventory check: a convergence claim covers the whole mapped
      # surface. Dimension scores claim only what an audit examined, so an
      # unswept row is unexamined code behind a clean-looking score - a
      # None on a dimension whose surface was never opened is silence, not
      # cleanliness. A PLAN.md without the section predates this check and
      # fails open with a stderr note.
      if [ -z "$violation" ] && [ -f "$root/PLAN.md" ]; then
        if grep -q '^## Surface inventory' "$root/PLAN.md"; then
          unswept="$(awk '{ sub(/\r$/, "") } /^## Surface inventory$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ { print; exit }' "$root/PLAN.md")"
          if [ -n "$unswept" ]; then
            violation="the Surface inventory in PLAN.md still lists an unswept row, first: $unswept; sweep it and record the commit, or record why it is out of scope, then re-declare convergence"
          fi
        else
          echo "jeffy stop hook: PLAN.md has no Surface inventory section; skipping the inventory check." >&2
        fi
      fi
      # P0-6: a swept row is a claim about code at a commit, and the code
      # moves. The prompt has always said a row whose implementing code
      # changed after its recorded commit is stale and flips back to unswept,
      # and nothing has ever enforced it: two published runs were refused by
      # the evaluator over exactly that, one carrying three rows recorded at a
      # commit its parser had moved past, the other a row recorded two
      # commits behind the header it covers. Both cost an invocation the
      # declaration then did not have.
      #
      # Staleness needs to know which paths a row owns, which is why a swept
      # row names the battery that swept it - the battery already declares
      # its paths, so the row plus the battery is enough to ask git. A row
      # naming no battery cannot be checked and is reported rather than
      # refused: existing trees predate the form, exactly as the Surface
      # inventory and Oracle class lines did when they shipped, and a check
      # that refused every row written before it existed would refuse the
      # whole corpus.
      if [ -z "$violation" ] && [ -f "$root/PLAN.md" ] \
        && command -v git >/dev/null 2>&1 \
        && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
        stale_row=""
        unlinked=0
        linked=0
        nopaths=0
        while IFS= read -r row; do
          [ -n "$row" ] || continue
          row_c="$(printf '%s' "$row" | grep -oE 'swept at [0-9a-f]{7,40}' | head -n 1 | awk '{print $3}')"
          row_b="$(printf '%s' "$row" | grep -oE '\.jeffy/probes/[A-Za-z0-9._-]+' | head -n 1)"
          if [ -z "$row_c" ] || [ -z "$row_b" ]; then
            unlinked=$((unlinked + 1))
            continue
          fi
          linked=$((linked + 1))
          pf="$root/$row_b/paths"
          # A battery with no paths file has no scope to check against; it
          # is counted and reported rather than silently passed (P0-8).
          [ -f "$pf" ] || { nopaths=$((nopaths + 1)); continue; }
          git -C "$root" rev-parse --verify --quiet "$row_c^{commit}" >/dev/null 2>&1 || continue
          # The battery's own paths file is the row's scope. A path that
          # changed since the row was recorded means the sweep certifies code
          # that is no longer there.
          # The template says one glob per line, and through 1.14.0 this
          # compared them as fixed strings (grep -F -x): a literal path
          # matched and a glob never did, so the gate was inert for 164 of
          # the corpus's 756 paths files and 27 swept rows sat stale behind
          # it unseen (P0-8). Each changed path is now matched against each
          # non-blank line as a shell glob - a literal is a glob that matches
          # itself, and `*` is allowed to cross `/`, because over-matching
          # asks for a re-sweep while under-matching certifies moved code.
          # A blank line would match nothing under case, but is skipped for
          # the same reason as before: an all-blank file is no scope at all
          # and the row is passed over rather than refused on a vacuous hit.
          pat="$(grep -v '^[[:space:]]*$' "$pf" 2>/dev/null)"
          [ -n "$pat" ] || continue
          moved=""
          while IFS= read -r chg; do
            [ -n "$chg" ] || continue
            while IFS= read -r gl; do
              [ -n "$gl" ] || continue
              # shellcheck disable=SC2254  # the pattern is the point
              case "$chg" in $gl) moved="$chg"; break ;; esac
            done <<EOF2
$pat
EOF2
            [ -n "$moved" ] && break
          done <<EOF2
$(git -C "$root" diff --name-only --relative "$row_c" HEAD 2>/dev/null)
EOF2
          if [ -n "$moved" ]; then
            stale_row="$(printf '%s' "$row" | cut -c1-90) (recorded at $row_c; $moved has changed since)"
            break
          fi
        done <<EOF
$(awk '{ sub(/\r$/, "") } /^## Surface inventory$/ { take = 1; next } /^## / { take = 0 } take && /^- \[x\]/ { print }' "$root/PLAN.md" 2>/dev/null)
EOF
        if [ -n "$stale_row" ]; then
          violation="a swept Surface inventory row is stale - $stale_row; re-sweep it and re-record the commit, or flip it back to unswept, then re-declare convergence"
        elif [ "$linked" -eq 0 ] && [ "$unlinked" -gt 0 ]; then
          echo "jeffy stop hook: no swept row names the battery that swept it ($unlinked rows), so staleness could not be derived; rows written from 1.14.0 carry it." >&2
        elif [ "$unlinked" -gt 0 ]; then
          echo "jeffy stop hook: $unlinked of $((linked + unlinked)) swept rows name no battery, so their staleness could not be derived." >&2
        fi
        if [ -z "$stale_row" ] && [ "$nopaths" -gt 0 ]; then
          echo "jeffy stop hook: $nopaths swept row(s) name a battery that has no paths file, so their staleness could not be derived; a battery declares the paths it covers in .jeffy/probes/<battery>/paths, one glob per line." >&2
        fi
      fi
      # P1-46: a Declined entry's stated reason is a claim the declaration
      # rests on, and it was the one state-file claim the closing sequence
      # read but never re-verified - zstd lost its terminal gate verdict to
      # a Declined premise the evaluator disproved in minutes. Every entry
      # under ## Declined must carry the command or measurement that
      # establishes its premise, written as Derivation: <command>; the one
      # exemption is the priced reason "cost: exceeds one iteration", which
      # is policy rather than premise and has nothing to re-run. Fails
      # closed: an underivable premise blocks exactly as an unparseable
      # severity does, and the remedy is cheap - record the derivation, or
      # move the entry back to the ledger.
      if [ -z "$violation" ] && [ -f "$root/BACKLOG.md" ] \
        && grep -q '^## Declined' "$root/BACKLOG.md"; then
        underived="$(awk '
          { sub(/\r$/, "") }
          /^## Declined$/ { take = 1; next }
          /^## / { take = 0 }
          take && /^- / && !/Derivation:/ && !/cost: exceeds one iteration/ { print substr($0, 1, 120); exit }
        ' "$root/BACKLOG.md")"
        if [ -n "$underived" ]; then
          violation="a Declined entry carries no recorded derivation, first: $underived; record the command or measurement that establishes its premise as Derivation: <command> (the priced reason cost: exceeds one iteration needs none), re-run it, then re-declare convergence"
        fi
      fi
      # Oracle declaration: the exit status of the project's own gate is the
      # only correctness signal this hook can read, and go-yaml showed how
      # little that can be worth. That run's Verify command exited 0 for 29
      # iterations across three runs while the repository's 402-case
      # conformance corpus never executed once - the only file importing it
      # carries a build tag for another platform, and the command's own
      # package selection never reached it - while the journal asserted twice
      # that the corpus was green and the evaluator gate countersigned both
      # claims. Scored independently afterwards, the external oracle moved by
      # nothing across 71 files and 8,174 inserted lines.
      # The hook deliberately does not decide whether a Verify command is
      # wide enough. That is a judgement about the project, and the whole
      # discipline here is to make the run state what it did rather than have
      # the shell guess at what it should have done. What it can require is
      # that the run wrote down what its command grades and what this
      # platform excludes, so a reader meets the narrowing at the claim
      # instead of discovering it afterwards. A PLAN.md carrying neither line
      # predates this and fails open, the way the Surface inventory shipped;
      # a file carrying one of the two is half-migrated and is named.
      if [ -z "$violation" ] && [ -f "$root/PLAN.md" ]; then
        # Prints "=<payload>" when the line exists and nothing when it does
        # not, so an absent line and an empty one stay distinguishable.
        oracle_field() { # $1 label
          awk -v lbl="$1" '
            { sub(/\r$/, "") }
            $0 == "## Verify command" { take = 1; next }
            /^## / { take = 0 }
            take && index($0, lbl ":") == 1 { print "=" substr($0, length(lbl) + 2); exit }
          ' "$root/PLAN.md"
        }
        oracle_unfilled() { # $1 payload; empty or a <...> placeholder is unanswered
          case "$1" in '' | '<'*'>') return 0 ;; *) return 1 ;; esac
        }
        oc_raw="$(oracle_field 'Oracle class')"
        ef_raw="$(oracle_field 'Environment fingerprint')"
        oc_val="${oc_raw#=}"
        oc_val="${oc_val#"${oc_val%%[![:space:]]*}"}"
        oc_val="${oc_val%"${oc_val##*[![:space:]]}"}"
        ef_val="${ef_raw#=}"
        ef_val="${ef_val#"${ef_val%%[![:space:]]*}"}"
        ef_val="${ef_val%"${ef_val##*[![:space:]]}"}"
        if [ -z "$oc_raw" ] && [ -z "$ef_raw" ]; then
          echo "jeffy stop hook: PLAN.md's Verify command section carries no Oracle class or Environment fingerprint line; skipping the oracle declaration check." >&2
        elif [ -z "$oc_raw" ]; then
          violation="PLAN.md's Verify command section carries an Environment fingerprint line but no Oracle class line; both are filled by the first audit and re-read at the declaration, so add the Oracle class line naming what the command actually grades - unit tests, a conformance corpus, a differential comparison, or a build only - then re-declare"
        elif [ -z "$ef_raw" ]; then
          violation="PLAN.md's Verify command section carries an Oracle class line but no Environment fingerprint line; add it naming the platform, the toolchain versions, and every test target this platform excludes, with the command that enumerated them, then re-declare"
        elif oracle_unfilled "$oc_val"; then
          violation="the Oracle class line in PLAN.md's Verify command section is unfilled; name what the Verify command actually grades - unit tests, a conformance corpus, a differential comparison against a reference implementation, or a build only - then re-declare"
        elif oracle_unfilled "$ef_val"; then
          violation="the Environment fingerprint line in PLAN.md's Verify command section is unfilled; name the platform, the toolchain versions, and every test target this platform excludes, enumerated by a command rather than asserted - a run once converged over 29 iterations while a build-tagged conformance corpus its command could not reach never ran at all - then re-declare"
        fi
      fi
      # Evaluator check: the adversarial gate is where the audits' misses were
      # found, and six of thirteen corpus convergences recorded no verdict at
      # all. The closing entry of this run is what must carry it - an earlier
      # entry's PASS answered an earlier tree - so the scan anchors on the last
      # primary heading stamped with this run id and reads that entry's body.
      # ROTATION and SALVAGE are additional entries rather than closing ones:
      # a closing iteration that pushes JOURNAL.md past 500 lines appends its
      # ROTATION entry after the declaration, and a scan anchored at the last
      # heading would then read a window holding no verdict and reject a
      # declaration that carries one. They are skipped, and the scan stops at
      # any heading that is not this run's primary entry rather than reading
      # on through it - otherwise a rotation entry's prose, or another run's,
      # supplies the verdict the closing entry never recorded.
      # The verdict is matched as a substring inside that entry: it normally
      # lives in the Verification field per journal-default, and a
      # field-anchored match would reject every legacy journal instead.
      # A substring in a model-written file is not evidence on its own, which
      # is why a PASS has to point at something from 1.7.0. The gate writes
      # .jeffy/evaluator/<run-id>-<n>.md naming every command it ran and that
      # command's real exit status, and a PASS is refused unless a regular
      # file is there for this run id, byte-identical to a copy committed in
      # HEAD, in a commit at or after the one the Converged line certifies.
      # Who wrote that file is UNENFORCEABLE at the shell layer and this check
      # does not pretend otherwise: a nominated command proves nothing and
      # re-executing one would only add a second model-authored command
      # execution. What it changes is the price of a false PASS - from eleven
      # typed characters to a fabricated forensic record that the checkpoint
      # commits and the repository then keeps, where a human reading the
      # receipt can find it.
      # Each clause of that test answers a way the negative form was silent.
      # A regular file, because test -s is true of a directory on every
      # filesystem that gives directories a size, so mkdir would have passed.
      # Committed and byte-identical against HEAD rather than git status said
      # nothing, because git says nothing about a path it has been told to
      # ignore, a path inside a nested repository, or a path marked
      # assume-unchanged - and the run itself can write .git/info/exclude, so
      # skipping the check wherever the artifact is ignored was an escape
      # hatch the graded party could open for itself. A project that ignores
      # .jeffy/ therefore has to un-ignore this one directory, and the
      # violation says so. And at or after the Converged hash, because the
      # contract re-invokes the gate in the iteration that declares - an
      # artifact from an invocation three iterations and two product commits
      # ago certifies a tree that no longer exists.
      # Second, Evaluator: unavailable no longer satisfies the stop. It let
      # the graded party certify the gate away in one line, and ta used it in
      # production; the run now ends blocked with the reason and convergence
      # waits for a relaunch where a sub-agent can be spawned.
      # Third, a journal that carries no entry for this run no longer fails
      # open here. It did through 1.6.0, for a rotated-away run id, but the
      # rotation rule keeps the last ten entries so a closing entry written
      # this turn is never among the rotated - and the fail-open let the run
      # decide whether the gate applied to it by choosing what it stamped on
      # its own heading. It is a violation now, and it re-feeds with the
      # evidence rather than ending anything, so a genuine heading defect is
      # repairable inside the budget.
      # One bound, stated rather than papered over: on a state file with no
      # started_at the run id degrades to the bare session prefix that every
      # run of the session shares, so a second run in that session could be
      # satisfied by the first run's artifact. Every /jeffy launch since
      # 1.5.0 writes started_at, so this reaches only state files older than
      # that, and the requirement is kept rather than waived there - waiving
      # it would turn a missing key into the bypass this check just closed.
      if [ -z "$violation" ]; then
        if [ ! -f "$root/JOURNAL.md" ]; then
          violation="JOURNAL.md is missing at $root, and the closing entry is where the evaluator verdict lives; restore the journal, record the verdict, then re-declare"
        else
          ev_verdict="$(awk -v tok="| $runid8 |" '
            { sub(/\r$/, "") }
            /^## iter / {
              split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
              if (index($0, tok) && t != "ROTATION" && t != "SALVAGE") {
                found = 1; ev = 0; un = 0; rj = 0; skip = 0; type = t
              } else {
                skip = 1
              }
              next
            }
            found && !skip && index($0, "Evaluator: PASS") { ev = 1 }
            found && !skip && index($0, "Evaluator: unavailable") { un = 1 }
            found && !skip && index($0, "Evaluator: REJECT") { rj = 1 }
            END {
              if (!found) print "none"
              else if (type == "RATCHET") print "ratchet"
              else if (rj) print "reject"
              else if (un) print "unavailable"
              else if (ev) print "pass"
              else print "missing"
            }
          ' "$root/JOURNAL.md")"
          # Artifact selection. Through 1.7.0 the path was keyed by run id
          # alone, so every re-invocation overwrote its predecessor and the
          # gate's forensic record was one version deep. A run that spent
          # three invocations published one artifact, the third; the earlier
          # two survived only as blobs in checkpoint commits, and a squash, a
          # rebase, a filtered export or a shallow clone reduces the record
          # to the last verdict. On the tree that made this concrete,
          # git log on that path returned exactly one commit - the squash -
          # and the earlier verdicts existed only on a local branch no clone
          # carries. That is the least durable artifact in the repository,
          # which is the opposite of what it was shipped for.
          # Keyed by run id and invocation ordinal, each verdict is a
          # distinct path no history operation can fold away, and
          # byte-distinctness becomes structural rather than a property of
          # the opening line that 1.7.0 had to patch at the content layer.
          # ev_art_ord is derived once near the run id, because the closing
          # extension reads it too.
          if [ -n "$ev_art_ord" ]; then
            ev_art=".jeffy/evaluator/$runid8-$ev_art_ord.md"
          else
            # A run launched under a pre-1.8.0 engine wrote the single path,
            # and the loop is designed to be relaunched over state files an
            # older engine left behind. Fall back to it rather than strand
            # that run; every test below applies to it unchanged.
            ev_art=".jeffy/evaluator/$runid8.md"
            [ -f "$root/$ev_art" ] && echo "jeffy stop hook: no ordinal-keyed evaluator artifact for run $runid8; reading the pre-1.8.0 single-path artifact $ev_art." >&2
          fi
          # Absolute invocation bound. The prompt owns the cap arithmetic,
          # because the midpoint rule turns on when the first invocation
          # landed and this hook cannot cheaply derive that. What it can
          # refuse is a declaration past every cap the contract could grant:
          # three recorded REJECTs, or a fourth artifact ordinal, leave no
          # invocation to produce the verdict declaring requires, whatever
          # the closing entry says.
          # Deliberately NOT enforced at two REJECTs. Where the cap is 3 a
          # second REJECT legally precedes a third invocation, which is the
          # path P1-3 opened for the run whose first verdict was REJECT, and
          # a hook that refused there would close it again. Below this bound
          # the prompt owns the rule and the artifact price guards it.
          if [ "$ev_rejects" -ge 3 ] || { [ -n "$ev_art_ord" ] && [ "$ev_art_ord" -ge 4 ]; }; then
            ev_verdict="capped"
          fi
          case "$ev_verdict" in
            capped)
              violation="this run's journal records $ev_rejects Evaluator: REJECT verdicts and its highest evaluator artifact ordinal is ${ev_art_ord:-none}, past every invocation cap the contract grants - 2, or 3 when the first invocation landed before the midpoint of the budget - so no invocation remains to produce the verdict a declaration requires; spend what budget is left in gate salvage on the findings the gate filed, then end the run blocked as 'blocked - N gate findings closed, declaration deferred', because convergence waits for the next run's fresh gate"
              ;;
            none)
              violation="JOURNAL.md holds no primary entry headed with the run id $runid8, and that entry is the only place the evaluator verdict is read from; write the closing entry under the run's own heading grammar, then re-declare"
              ;;
            ratchet)
              # The ratchet re-declares a tree an earlier run already
              # certified and never invokes the gate, which is why its type
              # exempts it from everything below - and that made the type the
              # cheapest bypass in the hook, seven characters where
              # unavailable took eleven, because nothing checked that the
              # certified commit predated this run. base_head, written by the
              # launch, is what a run cannot forge from inside itself: a
              # genuine ratchet names a commit at or before the tree the run
              # started on. A state file without the key predates this and
              # fails open with a note.
              ev_base="$(fm base_head)"
              if [ -z "$conv_hash" ]; then
                echo "jeffy stop hook: no Converged hash to date the ratchet against; skipping the ratchet's own check." >&2
              elif [ -z "$ev_base" ] || [ "$ev_base" = "none" ] \
                || ! git -C "$root" rev-parse --verify --quiet "$ev_base^{commit}" >/dev/null 2>&1; then
                echo "jeffy stop hook: the loop state carries no resolvable base_head; skipping the ratchet's own check." >&2
              elif ! git -C "$root" merge-base --is-ancestor "$conv_hash" "$ev_base" 2>/dev/null; then
                violation="the closing entry is typed RATCHET but the Converged hash $conv_hash is not an ancestor of the commit this run started on; a ratchet re-declares a tree an earlier run certified and never invokes the evaluator, so work committed during this run has to converge the ordinary way, through a fresh audit and the gate"
              fi
              ;;
            missing)
              violation="the closing entry records no Evaluator verdict; run the adversarial evaluator gate and record the verdict it returns, then re-declare - unless this run has spent every invocation its cap allows, in which case it may not re-invoke at all and ends blocked in gate salvage instead"
              ;;
            reject)
              violation="the closing entry records Evaluator: REJECT, which is not a verdict a run declares on; file each reason this run can reproduce and work them - with an invocation remaining, declare on a later PASS, and a second REJECT is not terminal while one is left; with none remaining the REJECT is terminal, so spend the rest of the budget in gate salvage on the findings the gate filed and end blocked as 'blocked - N gate findings closed, declaration deferred', never re-invoking and never declaring, because convergence waits for the next run's fresh gate"
              ;;
            unavailable)
              violation="the closing entry records Evaluator: unavailable; the adversarial gate is not optional and no convergence rests on its absence, so end the run with that reason and relaunch in a session where a sub-agent can be spawned"
              ;;
            pass)
              if [ ! -f "$root/$ev_art" ] || [ ! -s "$root/$ev_art" ]; then
                violation="the closing entry records Evaluator: PASS but $ev_art is not a file with content; the gate writes .jeffy/evaluator/$runid8-<n>.md, where n is the invocation ordinal, naming every command it ran and that command's real exit status, and a PASS with nothing behind it is eleven typed characters"
              elif command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
                ev_head_blob="$(git -C "$root" rev-parse --quiet --verify "HEAD:./$ev_art" 2>/dev/null || true)"
                ev_work_blob="$(git -C "$root" hash-object -- "$ev_art" 2>/dev/null || true)"
                ev_art_commit="$(git -C "$root" log -1 --format=%H -- "$ev_art" 2>/dev/null || true)"
                # HEAD:<path> resolves from the repository root, not from the
                # working directory, so the ./ prefix is what keeps this
                # correct in a project below the root - the same shape that
                # left both tree gates dead until --relative.
                if [ -z "$ev_head_blob" ]; then
                  violation="the evaluator artifact $ev_art is not committed in HEAD; the checkpoint commits it, which is what makes it evidence rather than a scratch file a later turn can rewrite unseen, so a project that ignores .jeffy/ has to un-ignore .jeffy/evaluator/ - then checkpoint it and re-declare"
                elif [ -z "$ev_work_blob" ] || [ "$ev_head_blob" != "$ev_work_blob" ]; then
                  violation="the evaluator artifact $ev_art in the working tree differs from the copy committed in HEAD; the artifact the gate wrote is the one that has to stand, so restore or checkpoint it and re-declare"
                elif [ -n "$conv_hash" ] && [ -n "$ev_art_commit" ] \
                  && ! git -C "$root" merge-base --is-ancestor "$conv_hash" "$ev_art_commit" 2>/dev/null; then
                  violation="the evaluator artifact $ev_art was last committed at $ev_art_commit, which predates the Converged hash $conv_hash; a PASS answers the tree the gate actually examined, so re-invoke the gate in the declaring iteration - a re-invocation writes the next ordinal, .jeffy/evaluator/$runid8-<n+1>.md, which the checkpoint commits alongside the one it supersedes - and re-declare"
                fi
              fi
              ;;
          esac
        fi
      fi
      if [ -z "$violation" ]; then
        # Verify-command check: the project's own gate must be green at the
        # converged stop. A missing PLAN.md or an absent timeout binary is
        # an infrastructure defect: skip with a stderr note, never trap.
        if [ ! -f "$root/PLAN.md" ]; then
          echo "jeffy stop hook: PLAN.md missing at $root; skipping the verify check." >&2
        else
          # The template writes prose under the heading and the command on a
          # "Command: <cmd>" line, and only that labeled line is ever run.
          # Section prose fed to bash -c is not a gate, it is an accidental
          # command whose exit status means nothing, so a section without
          # the label skips the check with a note instead.
          verify_cmd="$(awk '{ sub(/\r$/, "") } /^## Verify command$/ { take = 1; next } /^## / { take = 0 } take && /^Command: / { sub(/^Command: /, ""); print; exit }' "$root/PLAN.md")"
          # A markdown hard break is two trailing spaces, so the payload
          # arrives padded often enough to matter: the padding defeats the
          # backtick pattern below, which anchors on both ends, and pads the
          # command quoted back in a violation. Trim before anything reads it.
          verify_cmd="${verify_cmd#"${verify_cmd%%[![:space:]]*}"}"
          verify_cmd="${verify_cmd%"${verify_cmd##*[![:space:]]}"}"
          # Both empty payloads skip the check, and the note has to say which
          # one it is: a section with no Command line at all is a different
          # edit to PLAN.md than a Command line holding nothing.
          vc_skip=""
          if [ -z "$verify_cmd" ]; then
            vc_skip="carries no Command line"
          fi
          # Markdown reflex wraps the command in backticks, and bash -c reads
          # the pair as command substitution: it runs the output of the
          # command instead of the command itself and exits 127. Strip one
          # wrapping pair, only when both ends carry it and nothing between
          # them does - a payload whose first and last backticks belong to two
          # different substitutions is re-paired by a blind strip and then
          # executes a command nobody wrote, and it parses, so bash -n below
          # cannot catch it.
          case "$verify_cmd" in
            '`'*'`')
              vc_inner="${verify_cmd#'`'}"; vc_inner="${vc_inner%'`'}"
              case "$vc_inner" in
                *'`'*) ;;
                *) verify_cmd="$vc_inner" ;;
              esac
              ;;
          esac
          if [ -z "$verify_cmd" ] && [ -z "$vc_skip" ]; then
            vc_skip="carries an empty Command line"
          fi
          if [ -n "$vc_skip" ]; then
            echo "jeffy stop hook: the Verify command section of PLAN.md $vc_skip; skipping the verify check." >&2
          elif [ "$verify_cmd" != "none" ]; then
            # An annotated line (cargo test (419 tests)) is not runnable
            # shell, and running it reports the parse failure as a mystery
            # exit status. Parse it first and name the defect; never guess
            # which trailing text was the annotation, and never execute a
            # line that did not parse.
            if ! verify_syntax="$(printf '%s\n' "$verify_cmd" | bash -n 2>&1)"; then
              violation="the Verify command line ($verify_cmd) is not runnable shell (bash -n: $(printf '%s' "$verify_syntax" | head -n 1)); make the Command line a pure runnable command with no annotation, then re-declare convergence"
            else
              # A pipeline's exit status is its last stage's. A gate ending in
              # a pager or truncator therefore reports head/tail/cat, not the
              # suite - observed twice in one day (python-dotenv, libuv), 13
              # failing tests behind an exit 0. Lint only when a pipe exists:
              # a pipe-free 'cat file' is the user's own command.
              vc_lint=""
              case "$verify_cmd" in
                *'|'*)
                  vc_last="${verify_cmd##*|}"
                  vc_last="${vc_last#"${vc_last%%[![:space:]]*}"}"
                  case "$vc_last" in
                    head|head\ *|tail|tail\ *|less|less\ *|more|more\ *|cat|cat\ *)
                      vc_lint="${vc_last%% *}"
                      ;;
                  esac
                  ;;
              esac
              if [ -n "$vc_lint" ]; then
                violation="the Verify command ($verify_cmd) ends in $vc_lint, so its exit status is the truncator's, not the suite's; drop the trailing stage, then re-declare convergence"
              elif [ -z "$qv_lib" ]; then
                # The bound and the runner live in lib/quiet-verify.sh so the
                # engine holds exactly one timeout ladder. Without it there is
                # no way to re-run the gate, and a convergence this hook could
                # not verify is precisely what it exists to refuse: fail
                # closed and name the missing file. (P1-50)
                violation="the verify helper skills/jeffy/hooks/lib/quiet-verify.sh is missing, so the Verify command cannot be re-run; reinstall jeffy (the installer copies the whole hooks folder), then re-declare convergence"
              else
                vt="$(fm verify_timeout_seconds)"
                vt="$(jeffy_verify_bound "$root/PLAN.md" "$vt")"
                vlog="$(mktemp "${TMPDIR:-/tmp}/jeffy-hook-verify-XXXXXX")"
                jeffy_verify_run "$root" "$verify_cmd" "$vt" "$vlog"
                vrc=$?
                rm -f "$vlog"
                if [ "$vrc" -eq 124 ]; then
                  violation="the Verify command ($verify_cmd) exceeded the ${vt}s timeout; if the suite legitimately runs long, record its measured time as a labeled line reading Verify duration: <N>s in PLAN.md under Verify command (or set verify_timeout_seconds in the loop state file frontmatter), then get it green and re-declare convergence"
                elif [ "$vrc" -ne 0 ]; then
                  violation="the Verify command ($verify_cmd) exited $vrc; get it green, then re-declare convergence"
                fi
              fi
            fi
          fi
        fi
      fi
      if [ -z "$violation" ]; then
        if [ -n "$open_carried" ]; then
          carried_n="$(printf '%s\n' "$open_carried" | grep -c .)"
          echo "jeffy stop hook: convergence accepted with $carried_n carried Low finding(s) still open, first: $(printf '%s' "$open_carried" | head -n 1); the closing entry and the run report must name each carried Low, and the receipt publishes them." >&2
        fi
        rm -f "$state"
        exit 0
      fi
      ;;
  esac
fi

# Run-state facts, read once and used twice: the closing extension below turns
# on them and every re-feed states them. The model reads the last few journal
# entries and owns no arithmetic, so a budget it cannot see is a budget it
# feels rather than plans - "the arithmetic should have been done at iteration
# 7, not felt at iteration 9". Counting is the same section-scoped awk the
# promise path uses, per section here. A file that does not exist yields no
# count and the note simply omits that field: this is an accounting aid, never
# a gate, and an infrastructure gap must not block a re-feed.
open_now=""
open_next=""
open_later=""
if [ -f "$root/BACKLOG.md" ]; then
  read -r open_now open_next open_later <<< "$(awk '
    { sub(/\r$/, "") }
    /^## Now$/ { sec = 1; next }
    /^## Next$/ { sec = 2; next }
    /^## Later$/ { sec = 3; next }
    /^## / { sec = 0 }
    sec && /^- \[ \]/ { n[sec]++ }
    END { printf "%d %d %d", n[1], n[2], n[3] }
  ' "$root/BACKLOG.md")"
fi
unswept_rows=""
if [ -f "$root/PLAN.md" ] && grep -q '^## Surface inventory' "$root/PLAN.md"; then
  unswept_rows="$(awk '{ sub(/\r$/, "") } /^## Surface inventory$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ { n++ } END { printf "%d", n }' "$root/PLAN.md")"
fi
# P0-4 (1.11.0): the severity-aware blocking count, computed once beside the
# raw counts and read by the closing-extension grant, the refill guard, and
# the sweep-arithmetic note - one parse, three readers, because two severity
# parses in one hook is how they drift. Same floor as the closing rule: a
# task line whose severity is not a parseable Low blocks, so the count FAILS
# CLOSED on an unparseable line exactly as the declaration does. Empty when
# BACKLOG.md is absent, and every reader treats empty as cannot-evaluate.
open_hm=""
if [ -f "$root/BACKLOG.md" ]; then
  open_hm="$(awk '{ sub(/\r$/, "") } /^## (Now|Next|Later)$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ && $0 !~ /^- \[ \] [^ ]+ \(Low[,)]/ { n++ } END { printf "%d", n }' "$root/BACKLOG.md")"
fi
# P0-5: the High-or-unparseable count, beside the High-or-Medium one. Under
# coverage-first ordering only an open High outranks the map, so the sweep
# note and the fail-fast stop below key on this count, not open_hm. The same
# fail-closed floor: a task line whose severity is not a parseable Low or
# Medium counts as High, which keeps the early stop away from a ledger the
# hook cannot read. Empty when BACKLOG.md is absent, and every reader treats
# empty as cannot-evaluate.
open_high=""
if [ -f "$root/BACKLOG.md" ]; then
  open_high="$(awk '{ sub(/\r$/, "") } /^## (Now|Next|Later)$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ && $0 !~ /^- \[ \] [^ ]+ \((Low|Medium)[,)]/ { n++ } END { printf "%d", n }' "$root/BACKLOG.md")"
fi

# P0-5: the sweep history and its projection. rows_history on the state file
# is the unswept count observed at each turn end, oldest first, capped at the
# last 6 - enough for a rate, small enough to live in frontmatter. The rate
# is rows swept over the window; the projection is when the map clears at
# that rate. Both are said in the re-feed, because a count nobody is told to
# act on is not a schedule, and a projection nobody computes is a hope.
rows_hist="$(fm rows_history)"
hist_k=0; hist_first=""; hist_last=""; hist_deltas=""
proj_needed=""; new_rows_hist=""
# P0-7: a sample is taken only on a turn where the map was the top of the
# queue, so the rate is a sweep rate. Through 1.14.0 every turn end was
# sampled - the opening audit and every iteration an open High legitimately
# outranked the map - and the first sweep turn after the Highs closed
# projected from a window of zeros: Carbon's four rounds and chroma.js's
# first two all ended at iteration 4-5 of 10 on the turn their last High
# closed, 24 budgeted iterations never run. The open_high guard below still
# suppresses the stop itself; this keeps those turns out of the window too.
# An AUDIT turn is excluded by the same logic: it fills the map, it does not
# sweep it. A High turn's sample is dropped rather than the history reset,
# because a High that appears mid-sweep and is fixed next turn should not
# throw away the rate the sweep turns earned.
cur_iter_type=""
if [ -n "$run_tok" ]; then
  cur_iter_type="$(jeffy_iter_type "$root/JOURNAL.md" "| $runid8 |" "$iter")"
fi
if [ -n "$unswept_rows" ]; then
  case "$rows_hist" in
    '' | *[!0-9,]*) new_rows_hist="" ;;
    *) new_rows_hist="$rows_hist" ;;
  esac
  if [ "$open_high" = "0" ] && [ "$cur_iter_type" != "AUDIT" ]; then
    new_rows_hist="$new_rows_hist${new_rows_hist:+,}$unswept_rows"
  fi
  # keep the last 6 samples
  new_rows_hist="$(printf '%s' "$new_rows_hist" | awk -F, '{ s = (NF > 6) ? NF - 5 : 1; out = ""; for (i = s; i <= NF; i++) out = out (out == "" ? "" : ",") $i; print out }')"
  hist_k=0
  if [ -n "$new_rows_hist" ]; then
    hist_k="$(printf '%s' "$new_rows_hist" | awk -F, '{ print NF }')"
    hist_first="$(printf '%s' "$new_rows_hist" | awk -F, '{ print $1 }')"
    hist_last="$(printf '%s' "$new_rows_hist" | awk -F, '{ print $NF }')"
  fi
  if [ "$hist_k" -ge 2 ]; then
    hist_deltas=$((hist_first - hist_last))
    if [ "$hist_deltas" -gt 0 ] && [ "$unswept_rows" -gt 0 ]; then
      # ceil(unswept * (k-1) / deltas)
      proj_needed=$(( (unswept_rows * (hist_k - 1) + hist_deltas - 1) / hist_deltas ))
    fi
  fi
fi

# P0-5 fail-fast: when the observed rate says the map cannot clear inside
# what remains of the budget, end the run now with the arithmetic instead of
# spending the rest discovering it at exhaustion - the 100-iteration case.
# Guards, each deliberate: at least 4 samples so two audit-shaped opening
# iterations never trip it; an open High (or an unparseable line, same
# fail-closed parse) suppresses it, because a High legitimately outranks the
# map and its iterations are not sweep failures; a violation in flight keeps
# the rejection re-feed, which carries its own message; and at iter >= max
# the exhaustion path already reports. Three iterations are reserved for the
# convergence sequence the cleared map still needs.
if [ -n "$unswept_rows" ] && [ "$unswept_rows" != "0" ] \
  && [ "$open_high" = "0" ] && [ -z "$violation" ] \
  && [ "$hist_k" -ge 4 ] && [ "$iter" -lt "$max" ]; then
  # P0-7: the three-iteration reserve is the convergence sequence, and that
  # is only the next thing when nothing above Low is open. With a Medium
  # still on the ledger the run cannot declare inside this budget anyway,
  # and what the stop then protects is the chance to finish the map and
  # carry the Medium forward - so the reserve is not taken from the room.
  if [ "$open_hm" = "0" ]; then
    sweep_room=$((max - iter - 3))
  else
    sweep_room=$((max - iter))
  fi
  if [ "$hist_deltas" -le 0 ]; then
    echo "jeffy stop hook: the map is not clearing - $unswept_rows rows are unswept and 0 rows were swept over the last $((hist_k - 1)) iterations with nothing above Low on the ledger; ending the run early rather than spending the remaining $((max - iter)) iterations the same way (P0-5). The map and ledger carry to the next run." >&2
    rm -f "$state"
    exit 0
  elif [ -n "$proj_needed" ] && [ "$proj_needed" -gt "$sweep_room" ]; then
    echo "jeffy stop hook: the map cannot clear inside this budget - $unswept_rows rows are unswept, the observed rate is $hist_deltas rows over the last $((hist_k - 1)) iterations, so clearing needs about $proj_needed more sweep iterations against $sweep_room available after reserving 3 for the convergence sequence; ending the run early with the arithmetic rather than at exhaustion (P0-5). The map and ledger carry to the next run." >&2
    rm -f "$state"
    exit 0
  fi
fi

# Extension honesty: the +2 window buys the convergence sequence - the gate,
# fixes for tasks that gate filed, the declaration - never new work. A ledger
# that refills inside the window from any other source ends the run at once,
# honestly out of budget, with the filed tasks kept for the next run. The
# exception is read from the journal: when the last primary entry for this
# run is the EVALUATOR gate, its filings ride the one-transaction endgame.
# P0-4 (1.11.0): the trigger is a genuine refill, not the raw counts. An
# accurately scored open Low is legal at the declaration, so the Lows the
# window was granted over are legal inside it - a window granted with
# carried Lows died here one turn later as a false refill. What still ends
# the window: any open High or Medium (a window is never granted with one,
# so its presence is new work, measured by the same fail-closed parse the
# grant and the closing rule use), or the Low count rising above the count
# the grant recorded on the state file (extension_lows) - a Low filed inside
# the window is discovered work the prompt routes to the run report, and a
# ledger line for it is the refill this guard exists to end. A granted state
# file with no extension_lows key (a run granted before 1.11.0) cannot
# evaluate the delta and fails open to the High/Medium test alone.
ext_lows_rec="$(fm extension_lows)"
new_low_refill=""
cur_lows=""
if [ -n "$ext_lows_rec" ] && [ -n "$open_now" ] && [ -n "$open_hm" ]; then
  case "$ext_lows_rec" in *[!0-9]*) ;; *)
    cur_lows=$((open_now + open_next + open_later - open_hm))
    [ "$cur_lows" -gt "$ext_lows_rec" ] && new_low_refill=1
  ;; esac
fi
if [ "$(fm extension_granted)" = "1" ] && [ "$iter" -ge $((max - 1)) ] \
  && { { [ -n "$open_hm" ] && [ "$open_hm" != "0" ]; } || [ -n "$new_low_refill" ]; }; then
  last_type=""
  if [ -f "$root/JOURNAL.md" ]; then
    last_type="$(awk -v tok="| $runid8 |" '
      { sub(/\r$/, "") }
      /^## iter / && index($0, tok) {
        split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
        if (t != "ROTATION" && t != "SALVAGE") type = t
      }
      END { print type }
    ' "$root/JOURNAL.md")"
  fi
  if [ "$last_type" != "EVALUATOR" ]; then
    refill_kind="work above Low (blocking open $open_hm)"
    if [ -z "$open_hm" ] || [ "$open_hm" = "0" ]; then
      refill_kind="new Low tasks (open Lows $cur_lows against $ext_lows_rec recorded at the grant)"
    fi
    echo "jeffy stop hook: the ledger refilled inside the closing extension with $refill_kind (open tasks Now $open_now Next $open_next Later $open_later; last entry $last_type); the extension buys the convergence sequence, not new work - the Lows the grant recorded ride, new filings do not. Ending the run out of budget; the filed tasks stay on the ledger for the next run." >&2
    rm -f "$state"
    exit 0
  fi
fi

# Budget spent: end the run and let the session stop. A convergence claim
# whose checks failed gets a stderr note instead of a silent swallow.
# One exception, taken once: a run with nothing left but its convergence
# sequence, and that sequence costs two to three iterations nobody budgeted -
# six of fourteen runs across two projects died there with the work done.
# P0-4 (1.11.0): "nothing left" is the severity floor, not an empty ledger.
# Under P0-2 the canonical endgame shape is a swept map, zero open High or
# Medium, and carried Lows named on the record - the exact shape the raw-count
# test could never grant to. The ledger test here is now the same fail-closed
# severity test the declaration uses, read from the shared open_hm count. The
# grant is +2, recorded on the state file, and it applies just as much when a
# check rejected the promise at the last iteration: that rejection is
# repairable, and today it goes to stderr where nobody reads it. Conditions
# the hook cannot evaluate (no ledger, no inventory section) are not
# conditions it can grant on.
# Two shapes are not the boundary this grant was written for and take the
# plain exhaustion path instead. An iteration already past max is a
# hand-lowered budget, and extending it re-feeds arithmetic that runs
# negative ("-5 remain after it"), so only an iteration exactly at max
# grants. And the flag that makes the grant once-only is written by the
# rewriter at the frontmatter close, so a state file whose frontmatter never
# closes can never record it: the +2 would land every second turn forever
# with nothing accumulating to stop it. The guard tests the same ^---$ the
# rewriter counts, because a grant the rewriter cannot stamp is not a grant.
extension=""
ext_lows_grant=""
corrective=""
if [ "$iter" -ge "$max" ]; then
  fm_close="$(grep -c '^---$' "$state" 2>/dev/null || true)"
  case "$fm_close" in '' | *[!0-9]*) fm_close=0 ;; esac
  # A run past every invocation cap has no convergence sequence left for the
  # window to buy: it cannot re-invoke, so it cannot produce the verdict a
  # declaration needs, and two more iterations would only move the same
  # blocked ending two turns later. Bounded at the absolute cap for the same
  # reason the declaration check is - below it, a legal endgame still exists
  # and the extension is exactly what pays for it.
  if [ "$iter" -eq "$max" ] && [ "$fm_close" -ge 2 ] \
    && [ "$(fm extension_granted)" != "1" ] \
    && [ "$ev_rejects" -lt 3 ] && { [ -z "$ev_art_ord" ] || [ "$ev_art_ord" -lt 4 ]; } \
    && [ "$open_hm" = "0" ] \
    && [ "$unswept_rows" = "0" ]; then
    extension=1
    # The grant records the ledger's Low count on the state file, so the
    # refill guard above can tell the Lows the window was granted over from
    # a Low filed inside it. open_hm is "0" here, so the raw totals are the
    # Low count exactly.
    ext_lows_grant=$((open_now + open_next + open_later))
  elif [ -n "$violation" ] && [ "$fm_close" -ge 2 ] \
    && [ "$(fm corrective_granted)" != "1" ]; then
    # A rejected convergence at budget exhaustion used to go to stderr and
    # nowhere else. Nobody reads stderr, and the model's declaration and run
    # report stand in the transcript uncontradicted - the run looks converged
    # to the only audience that matters while the hook has already refused
    # it. The hook's one channel is blocking the stop, so it spends it once:
    # a single corrective re-feed that tells the run to record the rejection
    # and close honestly, never to fix and re-declare.
    # The grant is once per run, flagged on the state file the way the
    # closing extension is, and the flag can only be stamped where the
    # frontmatter actually closes - a state file that never closes could
    # never record it, and the corrective would fire every turn forever.
    # The closing extension takes precedence, because a rejection at max
    # with a clean ledger and a swept surface is repairable and the window
    # is what pays for repairing it. This is for the rejection that is not.
    corrective=1
  else
    if [ -n "$violation" ]; then
      echo "jeffy stop hook: convergence rejected ($violation) but the budget is spent; ending the run." >&2
    fi
    rm -f "$state"
    exit 0
  fi
fi

# P1-49: the wall-clock ceiling, and the per-iteration overrun note.
# "Budget counts turns, and a single turn is unbounded in time and cost" was
# true of every release before this one: a ten-turn budget had no upper bound
# in hours. These two keys give it one, and both are OFF unless the launch
# sets them - a default measured from nothing would be a number this engine
# refuses to publish anywhere else. For reference when choosing one: rounds
# of ten iterations in the published corpus run roughly 60 to 130 minutes.
#
# Placement is deliberate and load-bearing. This sits AFTER the closing
# extension is decided and BEFORE the re-feed, and it yields to an extension
# granted this turn: the window buys the convergence sequence, and a ceiling
# that killed a run three iterations from a certified declaration would cost
# more than the unbounded turn it was protecting against. A converged promise
# is never touched by either ceiling - that branch has already returned.
now_epoch="$(date +%s 2>/dev/null || echo 0)"
run_started="$(fm run_started_at)"
wall_max="$(fm max_wall_clock_seconds)"
iter_started="$(fm iteration_started_at)"
iter_max="$(fm max_iteration_seconds)"
case "$run_started" in '' | *[!0-9]*) run_started="" ;; esac
case "$wall_max" in '' | *[!0-9]*) wall_max=0 ;; esac
case "$iter_started" in '' | *[!0-9]*) iter_started="" ;; esac
case "$iter_max" in '' | *[!0-9]*) iter_max=0 ;; esac
wall_elapsed=""
if [ -n "$run_started" ] && [ "$now_epoch" -gt 0 ] && [ "$now_epoch" -ge "$run_started" ]; then
  wall_elapsed=$((now_epoch - run_started))
fi

# A malformed epoch fails open with a note rather than trapping the session,
# the way every other unparseable state value here does.
if [ -n "$(fm run_started_at)" ] && [ -z "$run_started" ]; then
  echo "jeffy stop hook: run_started_at is not an epoch integer; skipping the wall-clock ceiling." >&2
fi

# P2-26: context pressure, measured rather than counted. The engine re-feeds
# one session, so context accumulates within a run - the corpus prices that
# (python-dotenv's later runs re-filed findings earlier runs had already swept
# and scored clean). The campaign practice answers it by running each round as
# a fresh session, but that is tooling, and a user typing /jeffy 10 by hand
# gets one session with nothing saying so.
#
# The signal is the transcript's own growth, not an iteration count: an
# ordinal is a proxy for accumulation, while the transcript is the thing
# itself, and a ratio against this run's own first measurement calibrates to
# the project instead of to a number invented here. Advisory only - the
# closing rule governs, and a pre-registered budget is never cut short by it.
# The threshold is off unless set, exactly as the time ceilings are.
ctx_path="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
ctx_bytes=0
if [ -n "$ctx_path" ] && [ -f "$ctx_path" ]; then
  ctx_bytes="$(wc -c < "$ctx_path" 2>/dev/null | tr -d '[:space:]')"
  case "$ctx_bytes" in '' | *[!0-9]*) ctx_bytes=0 ;; esac
fi
ctx_base="$(fm context_base_bytes)"
case "$ctx_base" in '' | *[!0-9]* | 0) ctx_base="" ;; esac
new_ctx_base="$ctx_base"
# The baseline is this run's first measurement, taken once and carried.
if [ -z "$new_ctx_base" ] && [ "$ctx_bytes" -gt 0 ]; then
  new_ctx_base="$ctx_bytes"
fi
ctx_growth=""
if [ -n "$ctx_base" ] && [ "$ctx_base" -gt 0 ] && [ "$ctx_bytes" -gt 0 ]; then
  # One decimal place, in integer arithmetic: 10x the ratio, printed as x.y
  ctx_growth=$(( ctx_bytes * 10 / ctx_base ))
fi
ctx_max="$(fm max_context_growth)"
case "$ctx_max" in '' | *[!0-9]*) ctx_max=0 ;; esac
ctx_note=""
if [ "$ctx_max" -gt 0 ] && [ -n "$ctx_growth" ] && [ "$ctx_growth" -ge $((ctx_max * 10)) ]; then
  ctx_note="this session's transcript is $((ctx_growth / 10)).$((ctx_growth % 10))x its size at the first iteration of this run, past the ${ctx_max}x mark recorded on the state file; context accumulates within a run and a fresh session reads the state files rather than its own transcript, so prefer finishing the current task and closing the run over starting work that needs a long read - this is advice, and the closing rule still governs"
fi

overrun_flag="$(fm overrun)"
case "$overrun_flag" in 1) overrun_flag=1 ;; *) overrun_flag=0 ;; esac
new_overrun=0
overrun_note=""
if [ "$iter_max" -gt 0 ] && [ -n "$iter_started" ] && [ "$now_epoch" -ge "$iter_started" ]; then
  iter_elapsed=$((now_epoch - iter_started))
  if [ "$iter_elapsed" -gt "$iter_max" ]; then
    # The hook fires after the turn, so it cannot cut a long iteration short;
    # what it can do is refuse to let the next one be shaped the same way.
    if [ "$overrun_flag" = "1" ] && [ -z "$extension" ]; then
      echo "jeffy stop hook: two consecutive iterations exceeded the ${iter_max}s per-iteration ceiling (latest: iteration $iter at ${iter_elapsed}s); ending the run. Split the work or mark the task blocked in the next run." >&2
      rm -f "$state"
      exit 0
    fi
    new_overrun=1
    overrun_note="iteration $iter took ${iter_elapsed}s against a ${iter_max}s per-iteration ceiling; split the next task into work that fits, or mark it blocked with the reason - a second consecutive overrun ends the run"
  fi
fi

if [ "$wall_max" -gt 0 ] && [ -n "$wall_elapsed" ] && [ "$wall_elapsed" -gt "$wall_max" ] \
  && [ -z "$extension" ] && [ -z "$corrective" ]; then
  echo "jeffy stop hook: the run reached its wall-clock ceiling (${wall_elapsed}s against ${wall_max}s) at iteration $iter of $max; ending the run out of time rather than out of turns. The ledger and the map carry to the next run." >&2
  rm -f "$state"
  exit 0
fi

# Re-feed: advance the iteration counter in place, then block the stop with
# the iteration prompt as the reason. The prompt file was resolved at launch;
# a moved or removed jeffy skills folder leaves it stale, in which
# case ending the loop with a pointer beats re-feeding garbage.
if [ ! -f "$prompt_path" ]; then
  echo "jeffy stop hook: iteration prompt missing at $prompt_path (was the jeffy skill moved or removed?); ending the loop. Re-run /jeffy to relaunch." >&2
  rm -f "$state"
  exit 0
fi
# Iteration hygiene at the re-feed boundary: the finished iteration must
# have journaled itself under the heading grammar. A missing JOURNAL.md is
# an infrastructure defect and fails open with a stderr note; a violation
# rides the re-feed as evidence, and the budget bounds retries.
hygiene=""
next=$((iter + 1))
if [ -f "$root/JOURNAL.md" ]; then
  if ! grep -qF -- "## iter $iter/$max | $runid8" "$root/JOURNAL.md"; then
    hygiene="iteration $iter wrote no JOURNAL.md entry with the heading ## iter $iter/$max | $runid8; record it before proceeding"
  fi
  # Duplicate-index hygiene: a user interrupt can leave the journal ahead of
  # the loop counter, and the re-fed iteration then writes a second primary
  # entry under an index that already holds one - two entries headed 10/10
  # on one run, after which per-iteration accounting is silently wrong.
  # Warn only: the entry is what gets corrected, never the state.
  # Without the started_at token runid8 is the bare session prefix, which
  # every run of the session shares, so an earlier run's entry at the next
  # index reads as a desync that never happened. No token, no check.
  if [ -n "$run_tok" ] && grep -qF -- "## iter $next/$max | $runid8" "$root/JOURNAL.md"; then
    hygiene="$hygiene${hygiene:+; also }JOURNAL.md already holds a primary entry headed ## iter $next/$max | $runid8; the loop counter may have desynced (a user interrupt), so continue at the next free index and say so in the entry"
  fi
else
  echo "jeffy stop hook: JOURNAL.md missing at $root; skipping the journal-entry check." >&2
fi
# Tracked-tree check: modified or deleted tracked paths mean the iteration
# ended without its checkpoint. Untracked files never fire it - salvage and
# the checkpoint's git add -A own those, and they may be user droppings the
# hook has no right to demand committed. Skipped without git or a born HEAD.
if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
  # .jeffy/metrics/ is excluded because this hook writes it, and it writes it
  # AFTER the iteration's checkpoint by construction: every turn would then
  # open by telling the loop it forgot to commit a file the loop never wrote.
  # Nothing else under .jeffy/ is excused - a probe battery belongs in the
  # checkpoint like any other work. (P2-21)
  # The pathspec keeps a project below the repository root to its own tree,
  # and the filter is unanchored because status prints repo-root-relative
  # paths even then - anchored at the root it let proj/.jeffy/metrics/
  # through and fired every turn in a subdirectory project (P2-30).
  dirty="$(git -C "$root" status --porcelain --untracked-files=no -- . 2>/dev/null | grep -v '\.jeffy/metrics/' | head -n 1)"
  if [ -n "$dirty" ]; then
    hygiene="$hygiene${hygiene:+; also }iteration $iter ended with uncommitted tracked changes ($dirty); checkpoint them"
  fi
fi
# Archive integrity: JOURNAL-archive.md is append-only across every rotation
# and every run, so its entry count can never fall. A rotation that writes the
# archive instead of appending to it destroys the run's own record, and nothing
# else notices, because the live journal looks healthy afterwards. Only the
# instruction guarded this before, and the instruction was not enough: a
# 64-iteration run on a third-party project lost 18 entries this way. A run
# with no recorded baseline - never rotated, or launched before this shipped -
# never fires.
cur_archive="none"
naive_archive="none"
if [ -f "$root/JOURNAL-archive.md" ]; then
  # An entry heading names an iteration number; the journal template's
  # heading-grammar example begins "## iter <i>/<N>" and is not an entry,
  # so the count anchors on a digit. The strict count is always stored.
  cur_archive="$(grep -c '^## iter [0-9]' "$root/JOURNAL-archive.md" 2>/dev/null || true)"
  case "$cur_archive" in '' | *[!0-9]*) cur_archive=0 ;; esac
  naive_archive="$(grep -c '^## iter ' "$root/JOURNAL-archive.md" 2>/dev/null || true)"
  case "$naive_archive" in '' | *[!0-9]*) naive_archive=0 ;; esac
fi
last_archive="$(fm last_archive)"
# A baseline written before the strict anchor counted the template line, so a
# strict count one below it is the correction and not a loss. That escape is
# one-shot: it holds only until the state file carries archive_migrated, which
# the rewrite below stamps on with the strict baseline. A permanent escape
# would mask every later one-entry loss in an archive that keeps the template
# line, which is exactly the archive this migration exists for.
archive_migrated="$(fm archive_migrated)"
case "$last_archive" in
  '' | none | *[!0-9]*) ;;
  *)
    if [ "$cur_archive" = "none" ]; then
      hygiene="$hygiene${hygiene:+; also }JOURNAL-archive.md held $last_archive entries at the previous turn end and is now missing; the archive is append-only, so restore it"
    elif [ "$cur_archive" -lt "$last_archive" ]; then
      if [ "$archive_migrated" != "1" ] && [ "$naive_archive" -ge "$last_archive" ]; then
        echo "jeffy stop hook: migrated a legacy JOURNAL-archive.md baseline of $last_archive to the strict count $cur_archive; template lines are excluded from the count from here on." >&2
      else
        hygiene="$hygiene${hygiene:+; also }JOURNAL-archive.md fell from $last_archive entries to $cur_archive; rotation must append to the archive and never overwrite it, so restore the lost entries"
      fi
    fi
    ;;
esac

# Stall gate: progress since the previous turn end means a path outside the
# loop's own state moved, or BACKLOG.md changed - an audit that files tasks is
# progress even without a commit. HEAD moving is NOT the signal, though it was
# until 1.7.0: the iteration prompt mandates a checkpoint commit and a
# bookkeeping commit every iteration, so HEAD moves at every turn end of every
# git project - which is every project in the corpus - and both strikes were
# unreachable in all of them, the note as much as the stop. So when the heads
# differ the hook asks what moved, filtering the diff against the same loop
# memory the converged-tree test excludes: PLAN.md, BACKLOG.md, JOURNAL.md,
# JOURNAL-archive.md, .jeffy/ which holds the probe batteries, and the two
# files under .claude/ that the loop and the harness write for themselves.
# The iteration prompt's own stall rule carries that list too, aligned here.
# A recorded head this repository cannot resolve - a state file carried from
# another checkout, a rewritten history - is an infrastructure gap rather than
# evidence of a stall, and fails open as progress. A project that has no git
# HEAD at all, whether it never had one or lost it mid-run, falls back to the
# ledger signal alone, exactly as a non-git project does.
# The first re-feed initializes the baseline and never fires. A flat iteration
# rides a STALL note; the stall flag arms the second-strike stop. With no
# git HEAD and no ledger there is no signal at all: skip with a stderr note.
stall_note=""
new_stall=0
# Both are read after this gate by the oscillation and attempt-limit checks,
# and the gate assigns them only on the no-progress branch: under set -u an
# iteration that DID make progress would then abort the hook entirely, which
# is every healthy iteration. Initialised here so they always have a value.
stall_exempt=""
stall_type=""
cur_head="none"
if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
  cur_head="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo none)"
fi
cur_backlog="none"
if [ -f "$root/BACKLOG.md" ]; then
  # One definition of a ledger state change, carried by this hook and by the
  # iteration prompt in the same words. An item changed state when a task
  # line under Now, Next, or Later was
  # added, removed, edited, or moved between sections
  # - kept on one line because the validator pins that sentence in both
  # files, and a phrase wrapped across two comment lines is a phrase a
  # grep-based marker cannot find.
  # The whole-file cksum this replaces read any byte as
  # progress - a reworded Declined note, a Settled classes line, a blank line
  # - so an iteration that touched only prose registered as progress here
  # while the prompt's own stall rule called the same iteration a stall. Two
  # definitions of one signal is one definition too many, and it is the
  # laxer one that decides whether a run keeps going.
  # Migration is self-healing and costs one free pass: the first turn under
  # this version compares a stored whole-file cksum against the new digest,
  # mismatches, and reads a single spurious progress. Never a false stall,
  # and the next turn compares like with like.
  cur_backlog="$(awk '
    { sub(/\r$/, "") }
    /^## Now$/ { sec = "Now"; next }
    /^## Next$/ { sec = "Next"; next }
    /^## Later$/ { sec = "Later"; next }
    /^## / { sec = "" }
    sec != "" && /^- \[[ b]\]/ { print sec "|" $0 }
  ' "$root/BACKLOG.md" | cksum | tr ' \t' '--')"
fi
# P0-5 (P1-47): the inventory signal. A sweep iteration by construction
# touches only PLAN.md and .jeffy/, which was exactly the no-progress
# signature, so runs paired sweeps with unrelated Lows purely to survive
# this gate - scheduling by hand that the engine forced. A Surface inventory
# row that changed state (flipped, added, removed, re-recorded) is progress,
# read over the row lines alone so PLAN.md prose stays out of it, the same
# shape as the ledger signal above.
cur_inventory="none"
if [ -f "$root/PLAN.md" ] && grep -q '^## Surface inventory' "$root/PLAN.md"; then
  cur_inventory="$(awk '
    { sub(/\r$/, "") }
    /^## Surface inventory$/ { take = 1; next }
    /^## / { take = 0 }
    take && /^- \[[ xb]\]/ { print }
  ' "$root/PLAN.md" | cksum | tr ' \t' '--')"
fi
last_head="$(fm last_head)"
last_backlog="$(fm last_backlog)"
last_inventory="$(fm last_inventory)"
stall_flag="$(fm stall)"
case "$stall_flag" in 1) stall_flag=1 ;; *) stall_flag=0 ;; esac
# Consecutive ceremony iterations, counted so the exemption below is bounded.
ceremony_n="$(fm stall_ceremony)"
case "$ceremony_n" in '' | *[!0-9]*) ceremony_n=0 ;; esac
new_ceremony=0
if [ "$cur_head" = "none" ] && [ "$cur_backlog" = "none" ]; then
  echo "jeffy stop hook: no git HEAD and no BACKLOG.md; skipping the stall check." >&2
elif [ -n "$last_head" ] || [ -n "$last_backlog" ] || [ -n "$last_inventory" ]; then
  progress=0
  if [ "$cur_backlog" != "$last_backlog" ]; then
    progress=1
  elif [ -n "$last_inventory" ] && [ "$cur_inventory" != "$last_inventory" ]; then
    # A missing baseline (first turn under this version) is not a signal;
    # a recorded one that moved is a row flip and counts as progress.
    progress=1
  elif [ "$cur_head" != "none" ] && [ "$cur_head" != "$last_head" ]; then
    if [ -n "$last_head" ] && [ "$last_head" != "none" ] \
      && git -C "$root" rev-parse --verify --quiet "$last_head^{commit}" >/dev/null 2>&1; then
      moved="$(git -C "$root" diff --name-only --relative "$last_head" "$cur_head" 2>/dev/null | grep -vE "$JEFFY_LOOP_MEMORY_RE" | head -n 1)"
      [ -n "$moved" ] && progress=1
    else
      progress=1
    fi
  fi
  if [ "$progress" = "1" ]; then
    new_stall=0
  else
    # The ceremony types are exempt from the strike. A closeout audit that
    # files nothing legitimately changes state files only, and so do the
    # evaluator gate, a ratchet re-declaration and a wrapup; a run of them is
    # the correct shape of the convergence sequence, not a stall, and a gate
    # that ended the run there would kill converging runs at the finish line.
    # Every other primary type is a task id and gets no exemption.
    # An exempt iteration is transparent: no note, no strike, and the flag
    # carried through unchanged, so a flat task iteration on either side of
    # the ceremony still counts. The prompt's own stall rule matches.
    # Bounded, though, because the type is eleven characters the graded party
    # types into its own journal, and every other model-authored claim in
    # this hook is re-derived rather than believed. The prompt puts the
    # convergence sequence at two to three iterations, so three consecutive
    # exemptions is the whole legitimate ceremony and a fourth is a run
    # typing AUDIT at a wall: past the cap the ordinary strike logic resumes.
    # The lookup needs a run token to mean anything. Without started_at the
    # run id is the bare session prefix every run of the session shares, and
    # an earlier run's audit at the same index would exempt this run's flat
    # task iteration - the same reason the duplicate-index check above is
    # disabled there. No token, no exemption.
    stall_exempt=""
    if [ -f "$root/JOURNAL.md" ] && [ -n "$run_tok" ]; then
      # Last match wins, not first: the journal is append-only and a user
      # interrupt can leave two primary entries at one index (the hygiene
      # check above warns about exactly that), where the current entry is the
      # later one. The evaluator and ledger-refill scans read it the same way.
      # The status column rides along with the task name: an iteration whose
      # entry honestly reads blocked did real work and refused an unearned
      # checkpoint (a verify still in flight is the canonical case), and
      # scoring that refusal as no-progress once ended a run three minutes
      # before its own verify returned green. The same ceremony cap bounds
      # it, so a run that cries blocked forever still stalls. (P1-29)
      stall_line="$(awk -v tok="| $runid8 |" -v it="$iter" '
        { sub(/\r$/, "") }
        /^## iter / && index($0, tok) {
          split($0, f, "|"); t = f[4]; gsub(/^[ \t]+|[ \t]+$/, "", t)
          if (t == "ROTATION" || t == "SALVAGE") next
          n = f[1]; sub(/^## iter[ \t]*/, "", n); sub(/\/.*/, "", n)
          st = f[5]; gsub(/^[ \t]+|[ \t]+$/, "", st)
          if (n + 0 == it + 0) { type = t; status = st }
        }
        END { print type "\t" status }
      ' "$root/JOURNAL.md")"
      stall_type="$(printf '%s' "$stall_line" | cut -f1)"
      stall_status="$(printf '%s' "$stall_line" | cut -f2)"
      case "$stall_type" in
        AUDIT | EVALUATOR | RATCHET | WRAPUP) stall_exempt="$stall_type" ;;
        *) case "$stall_status" in blocked) stall_exempt="blocked" ;; esac ;;
      esac
    fi
    if [ -n "$stall_exempt" ] && [ "$ceremony_n" -lt 3 ]; then
      new_ceremony=$((ceremony_n + 1))
      new_stall="$stall_flag"
    elif [ "$stall_flag" = "1" ] && [ -z "$corrective" ]; then
      # Second strike: the prompted hard-blocker close-out did not happen,
      # so the hook ends the stalled run itself, the way budget exhaustion
      # does - state deleted, stop allowed, evidence on stderr. A closing
      # extension decided earlier this turn is written by the rewrite below,
      # which this path never reaches, so the grant is forfeited: say so
      # rather than let the run die one iteration from the finish line with
      # no account of the two it was just given.
      stall_ext=""
      if [ -n "$extension" ]; then
        stall_ext=" the closing extension decided this turn is forfeited with it;"
      fi
      echo "jeffy stop hook: two consecutive flat iterations (latest: iteration $iter) with nothing changed outside the loop state files;$stall_ext ending the run as stalled." >&2
      rm -f "$state"
      exit 0
    else
      # The second strike yields to a corrective re-feed decided this turn.
      # Both want to end the same turn, and letting the stall stop win puts
      # the refused convergence back on stderr where nobody reads it - the
      # exact silence the corrective exists to break. Yielding is bounded:
      # the corrective turn is the run's last turn ever, because the grant
      # flag ends the run at the next stop whatever that turn did, so the
      # stall gate concedes at most one turn and the record closes honestly.
      [ -n "$stall_exempt" ] && new_ceremony=$((ceremony_n + 1))
      new_stall=1
      stall_note="iteration $iter made no progress (nothing changed since the previous turn end outside PLAN.md, BACKLOG.md, JOURNAL.md, JOURNAL-archive.md, .jeffy/ and the loop's own files under .claude/, no BACKLOG.md task line changed state, and no Surface inventory row changed state); a second consecutive flat iteration ends the run"
    fi
  fi
fi

# P1-48: oscillation and the attempt limit, the two thrash shapes the stall
# gate cannot see. It asks whether anything moved; these ask whether what
# moved went anywhere. A run that changes a source file every iteration and
# reverts it two iterations later passes the stall gate every single time and
# can burn a whole budget looking productive.
#
# The trail is one state key rather than six, in the shape rows_history
# already uses: iteration|attempted-task|content-hash|changed-count, last 6.
fp_hist="$(fm fingerprints)"
# The attempted task is read here rather than borrowed from the stall gate:
# that gate only looks up the journal when it found NO progress, and a run
# burning attempts on one stubborn task is making progress by its measure
# every time. Same lookup, same last-match-wins rule, no dependency on which
# branch the stall gate took.
fp_task="ceremony"
if [ -f "$root/JOURNAL.md" ] && [ -n "$run_tok" ]; then
  fp_type="$cur_iter_type"
  case "$fp_type" in
    '' | AUDIT | EVALUATOR | RATCHET | WRAPUP | SWEEP | SALVAGE | ROTATION) fp_task="ceremony" ;;
    *) fp_task="$fp_type" ;;
  esac
fi
fp_hash="none"
fp_changed=0
if [ "$cur_head" != "none" ]; then
  fp_hash="$(jeffy_content_tree_hash "$root")"
  if [ -n "$last_head" ] && [ "$last_head" != "none" ] \
    && git -C "$root" rev-parse --verify --quiet "$last_head^{commit}" >/dev/null 2>&1; then
    fp_changed="$(git -C "$root" diff --name-only --relative "$last_head" "$cur_head" 2>/dev/null | grep -vcE "$JEFFY_LOOP_MEMORY_RE")"
    case "$fp_changed" in '' | *[!0-9]*) fp_changed=0 ;; esac
  fi
fi
new_fp_hist="$fp_hist${fp_hist:+;}$iter|$fp_task|$fp_hash|$fp_changed"
new_fp_hist="$(printf '%s' "$new_fp_hist" | awk -F';' '{ s = (NF > 6) ? NF - 5 : 1; out = ""; for (i = s; i <= NF; i++) out = out (out == "" ? "" : ";") $i; print out }')"

osc_flag="$(fm oscillation)"
case "$osc_flag" in 1) osc_flag=1 ;; *) osc_flag=0 ;; esac
new_osc="$osc_flag"
osc_note=""
attempt_note=""
# P1-57: a ceremony iteration - an audit that files tasks, a sweep, a gate
# that files, a wrapup - leaves the content hash where it was by design, and
# three in a row read as a revert-revert. The fingerprint trail still records
# them; the comparison skips them. The no-progress exemption below already
# covered the flat case; this covers the progressing one, which the false
# strikes on decimal.js and chroma.js all were.
osc_skip=""
case "$cur_iter_type" in AUDIT | EVALUATOR | RATCHET | WRAPUP | SWEEP) osc_skip=1 ;; esac
if [ "$fp_hash" != "none" ] && [ -z "$stall_exempt" ] && [ -z "$osc_skip" ]; then
  # Oscillation: this iteration's content hash is one the tree already had
  # two or three iterations ago. Two back is a straight revert; three back
  # catches the fix-fix-revert-revert shape.
  fp_back2="$(printf '%s' "$fp_hist" | awk -F';' '{ if (NF >= 2) { split($(NF-1), a, "|"); print a[3] } }')"
  fp_back3="$(printf '%s' "$fp_hist" | awk -F';' '{ if (NF >= 3) { split($(NF-2), a, "|"); print a[3] } }')"
  fp_back2_it="$(printf '%s' "$fp_hist" | awk -F';' '{ if (NF >= 2) { split($(NF-1), a, "|"); print a[1] } }')"
  fp_back3_it="$(printf '%s' "$fp_hist" | awk -F';' '{ if (NF >= 3) { split($(NF-2), a, "|"); print a[1] } }')"
  fp_match=""
  if [ -n "$fp_back2" ] && [ "$fp_hash" = "$fp_back2" ]; then
    fp_match="$fp_back2_it"
  elif [ -n "$fp_back3" ] && [ "$fp_hash" = "$fp_back3" ]; then
    fp_match="$fp_back3_it"
  fi
  if [ -n "$fp_match" ]; then
    if [ "$osc_flag" = "1" ] && [ -z "$extension" ] && [ -z "$corrective" ]; then
      echo "jeffy stop hook: the tree has returned to a state it already held for the second time (iteration $iter matches iteration $fp_match, excluding loop memory); the run is oscillating rather than progressing, so it ends here. The ledger and the map carry to the next run." >&2
      rm -f "$state"
      exit 0
    fi
    new_osc=1
    osc_note="iteration $iter left the tree byte-identical to how iteration $fp_match left it, excluding loop memory - work done since has been undone, so decide which version is right and record why in the journal; a second occurrence ends the run"
  else
    new_osc=0
  fi

  # Attempt limit: the same task attempted three iterations running and still
  # open. "At most 3 fix attempts, then mark it blocked with a reason" has
  # been in the iteration prompt since the beginning and was the last rule of
  # its weight that nothing enforced.
  if [ "$fp_task" != "ceremony" ] && [ -f "$root/BACKLOG.md" ]; then
    # The trail holds the iterations BEFORE this one, so three consecutive
    # attempts means this iteration plus the last two entries - not the two
    # before those, which was an off-by-one that left this unreachable.
    fp_prev1="$(printf '%s' "$fp_hist" | awk -F';' '{ if (NF >= 1) { split($NF, a, "|"); print a[2] } }')"
    fp_prev2="$(printf '%s' "$fp_hist" | awk -F';' '{ if (NF >= 2) { split($(NF-1), a, "|"); print a[2] } }')"
    if [ "$fp_task" = "$fp_prev1" ] && [ "$fp_task" = "$fp_prev2" ] \
      && grep -qE "^- \[ \] $fp_task( |\()" "$root/BACKLOG.md"; then
      attempt_note="$fp_task has been the attempted task for three consecutive iterations and is still open; the rule is at most three fix attempts, so mark it [b] with the reason it resisted and move to the next item rather than spending a fourth"
    fi
  fi
fi

# The extension is granted by the same rewrite that advances the counter, so
# the new budget is on the state file before anything reads it: the iteration
# suffix, the run-state note, and the next turn's budget test all see max+2.
if [ -n "$extension" ]; then
  max=$((max + 2))
fi

tmp="$state.tmp"
# The rewriter owns the keys it names and prints every other line verbatim,
# so the schema is additive: a state file carrying keys this version never
# heard of survives the re-feed untouched. max_iterations and
# extension_granted are owned only on the re-feed that grants the extension;
# on every ordinary re-feed they fall through to the verbatim print, because a
# max_iterations rewritten unconditionally would re-extend the run every turn.
# archive_migrated rides along with the strict archive baseline it certifies:
# the baseline this rewrite stores is strict, so the naive escape above has
# done its one job and must never be taken again.
if awk -v n="$next" -v lh="$cur_head" -v lb="$cur_backlog" -v li="$cur_inventory" -v rh="$new_rows_hist" -v sf="$new_stall" -v sc="$new_ceremony" -v la="$cur_archive" -v mx="$max" -v ex="$extension" -v co="$corrective" -v el="$ext_lows_grant" -v it="$now_epoch" -v ov="$new_overrun" -v fp="$new_fp_hist" -v os="$new_osc" -v cb="$new_ctx_base" '
  /^---$/ { fmc++; if (fmc == 2) { if (!slh) print "last_head: " lh; if (!slb) print "last_backlog: " lb; if (!sli) print "last_inventory: " li; if (rh != "" && !srh) print "rows_history: " rh; if (!ssf) print "stall: " sf; if (!ssc) print "stall_ceremony: " sc; if (!sla) print "last_archive: " la; if (!sam) print "archive_migrated: 1"; if (it != "0" && !sit) print "iteration_started_at: " it; if (!sov) print "overrun: " ov; if (fp != "" && !sfp) print "fingerprints: " fp; if (!sos) print "oscillation: " os; if (cb != "" && !scb) print "context_base_bytes: " cb; if (ex && !sex) print "extension_granted: 1"; if (ex && el != "" && !sel) print "extension_lows: " el; if (co && !sco) print "corrective_granted: 1" } print; next }
  fmc == 1 && /^iteration: / { print "iteration: " n; next }
  fmc == 1 && /^last_inventory: / { print "last_inventory: " li; sli = 1; next }
  fmc == 1 && rh != "" && /^rows_history: / { print "rows_history: " rh; srh = 1; next }
  fmc == 1 && ex && /^max_iterations: / { print "max_iterations: " mx; next }
  fmc == 1 && ex && /^extension_granted: / { print "extension_granted: 1"; sex = 1; next }
  fmc == 1 && ex && el != "" && /^extension_lows: / { print "extension_lows: " el; sel = 1; next }
  fmc == 1 && co && /^corrective_granted: / { print "corrective_granted: 1"; sco = 1; next }
  fmc == 1 && /^last_head: / { print "last_head: " lh; slh = 1; next }
  fmc == 1 && /^last_backlog: / { print "last_backlog: " lb; slb = 1; next }
  fmc == 1 && /^stall: / { print "stall: " sf; ssf = 1; next }
  fmc == 1 && /^stall_ceremony: / { print "stall_ceremony: " sc; ssc = 1; next }
  fmc == 1 && /^last_archive: / { print "last_archive: " la; sla = 1; next }
  fmc == 1 && /^archive_migrated: / { print "archive_migrated: 1"; sam = 1; next }
  fmc == 1 && it != "0" && /^iteration_started_at: / { print "iteration_started_at: " it; sit = 1; next }
  fmc == 1 && /^overrun: / { print "overrun: " ov; sov = 1; next }
  fmc == 1 && fp != "" && /^fingerprints: / { print "fingerprints: " fp; sfp = 1; next }
  fmc == 1 && /^oscillation: / { print "oscillation: " os; sos = 1; next }
  fmc == 1 && cb != "" && /^context_base_bytes: / { print "context_base_bytes: " cb; scb = 1; next }
  { print }
' "$state" > "$tmp"; then
  mv "$tmp" "$state"
else
  rm -f "$tmp"
  echo "jeffy stop hook: could not update $state; not re-feeding." >&2
  exit 0
fi
reason="$(cat "$prompt_path")"
if [ -n "$focus" ]; then
  reason="$reason Focus this run on: $focus."
fi
reason="$reason This is jeffy iteration $next of $max for this run."
if [ -n "$violation" ] && [ -z "$corrective" ]; then
  reason="$reason CONVERGENCE REJECTED by the stop hook: $violation. Fix this, then re-declare convergence with the promise phrase."
fi
# The corrective note replaces that one rather than joining it: telling a run
# with no budget left to fix and re-declare is an instruction it cannot
# carry out, and the point here is an honest close, not another attempt.
if [ -n "$corrective" ]; then
  reason="$reason CORRECTIVE: the convergence you declared this turn was refused ($violation), and the budget is spent, so this run does not converge. Do no further work and do not re-declare: append a journal entry recording the refusal and its reason, then close with a run report that states the run ended out of budget without converging, naming what remains for the next run."
fi
if [ -n "$hygiene" ]; then
  reason="$reason ITERATION HYGIENE: $hygiene."
fi
if [ -n "$stall_note" ]; then
  reason="$reason STALL: $stall_note."
fi
if [ -n "$overrun_note" ]; then
  reason="$reason ITERATION OVERRUN: $overrun_note."
fi
if [ -n "$osc_note" ]; then
  reason="$reason OSCILLATION: $osc_note."
fi
if [ -n "$attempt_note" ]; then
  reason="$reason ATTEMPT LIMIT: $attempt_note."
fi
if [ -n "$ctx_note" ]; then
  reason="$reason CONTEXT PRESSURE: $ctx_note."
fi
if [ -n "$extension" ]; then
  reason="$reason CLOSING EXTENSION: one-time +2 iterations granted because only the convergence sequence remains. No further extension will be granted."
fi
# The run-state note closes the reason, after the evidence the other notes
# carry: it is the arithmetic, not a finding. Fields the hook could not count
# are absent rather than guessed.
run_state="RUN STATE: iteration $next of $max; $((max - next)) remain after it"
if [ -n "$open_now" ]; then
  run_state="$run_state; open tasks Now $open_now Next $open_next Later $open_later"
fi
if [ -n "$unswept_rows" ]; then
  run_state="$run_state; unswept rows $unswept_rows"
fi
# The wall figure rides the same line as the iteration arithmetic, so the run
# plans against elapsed time the way it plans against remaining turns. It is
# stated whenever it can be measured, ceiling or no ceiling: awareness is
# free, and a run that can see the clock can choose to wrap up before one is
# ever imposed.
if [ -n "$ctx_growth" ]; then
  run_state="$run_state; context $((ctx_growth / 10)).$((ctx_growth % 10))x"
fi
if [ -n "$wall_elapsed" ]; then
  if [ "$wall_max" -gt 0 ]; then
    run_state="$run_state; wall $((wall_elapsed / 60))m/$((wall_max / 60))m"
  else
    run_state="$run_state; wall $((wall_elapsed / 60))m (no ceiling set)"
  fi
fi
run_state="$run_state; jeffy v$JEFFY_VERSION"
reason="$reason $run_state."
# Zero blocking findings over a swept surface is not a finished run: the
# closing audit, the evaluator gate and the declaration are still to come,
# and runs that did not know that spent their last iterations discovering
# it. P0-4 (1.11.0): the test is the shared severity count, not the raw
# totals - the canonical endgame carries its accurately scored Lows, and a
# note keyed to an empty ledger never reached exactly the runs that needed
# its arithmetic most.
if [ "$open_hm" = "0" ] && [ "$unswept_rows" = "0" ]; then
  reason="$reason Only the convergence sequence remains; it typically needs 2 to 3 iterations (closing audit, evaluator gate, declaration); plan the remaining $((max - next)) accordingly."
  if [ "$open_now" != "0" ] || [ "$open_next" != "0" ] || [ "$open_later" != "0" ]; then
    reason="$reason Open Lows are carried to the declaration, named in the declaring entry and the receipt; they are not the remaining work."
  fi
fi
# P0-5 (P1-39 before it): when nothing on the ledger outranks the map - no
# open High, no unparseable severity, the same fail-closed parse the early
# stop uses - and rows are still unswept, say the sweep arithmetic out loud,
# with the projection when the history can support one. Six targets ended
# runs with the gate never due because every iteration went to the ledger
# while the map sat unfilled; under coverage-first ordering only an open
# High keeps the note silent, because only a High outranks mapping now - a
# Medium queues behind the coverage the declaration requires.
if [ -n "$unswept_rows" ] && [ "$unswept_rows" != "0" ]; then
  if [ "$open_high" = "0" ]; then
    reason="$reason Sweep arithmetic: $unswept_rows rows are unswept with $((max - next + 1)) iterations left including this one; the map outranks everything but an open High, so sweeping is the top item now."
    if [ "$hist_k" -ge 2 ]; then
      if [ "$hist_deltas" -gt 0 ] && [ -n "$proj_needed" ]; then
        reason="$reason Observed rate: $hist_deltas rows swept over the last $((hist_k - 1)) iterations, projecting the map clearing around iteration $((next + proj_needed - 1)) of $max."
      else
        reason="$reason Observed rate: 0 rows swept over the last $((hist_k - 1)) iterations; at this rate the map never clears, and the run will be ended early once the shortfall is established."
      fi
    fi
  fi
fi
jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
exit 0
