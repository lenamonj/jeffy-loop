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

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  root="$(pwd)"
fi
state="$root/.claude/jeffy-loop.local.md"
[ -f "$state" ] || exit 0

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

case "$iter$max" in
  '' | *[!0-9]*)
    echo "jeffy stop hook: malformed state file $state (iteration=$iter, max_iterations=$max); not re-feeding. Run /cancel-jeffy or delete the file." >&2
    exit 0
    ;;
esac

# Completion promise: prefer the last_assistant_message field newer CLIs put
# on stdin; fall back to the last assistant entry of the JSONL transcript.
violation=""
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
      if [ ! -f "$root/BACKLOG.md" ]; then
        echo "jeffy stop hook: BACKLOG.md missing at $root; accepting the promise unchecked." >&2
        rm -f "$state"
        exit 0
      fi
      open_tasks="$(awk '{ sub(/\r$/, "") } /^## (Now|Next|Later)$/ { take = 1; next } /^## / { take = 0 } take && /^- \[ \]/ { print }' "$root/BACKLOG.md")"
      if [ -n "$open_tasks" ]; then
        violation="BACKLOG.md still lists open tasks in Now, Next, or Later, first: $(printf '%s' "$open_tasks" | head -n 1)"
      elif command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
        # Converged-hash check: the latest Converged line must name a commit
        # in this repository, and nothing but loop state may have changed
        # between it and HEAD - the ratchet's definition of an unchanged
        # tree. HEAD-exact equality would be unsatisfiable wherever the state
        # files are tracked, because the closing checkpoint commits the
        # Converged line itself. Skipped in non-git projects. The line is
        # markdown a model writes, so a leading list marker and backticks
        # around the hash are tolerated; the section anchoring is not.
        conv_hash="$(awk '{ sub(/\r$/, "") } /^## Converged$/ { take = 1; next } /^## / { take = 0 } take && /^[-*] +Converged: / { sub(/^[-*] +/, "") } take && /^Converged: / { h = $2; gsub(/^`|`$/, "", h) } END { if (h) print h }' "$root/BACKLOG.md")"
        if [ -z "$conv_hash" ] || ! git -C "$root" rev-parse --verify --quiet "$conv_hash^{commit}" >/dev/null 2>&1; then
          violation="the ## Converged section of BACKLOG.md does not name a commit in this repository; append the Converged line for the certified checkpoint"
        else
          nonstate="$(git -C "$root" diff --name-only "$conv_hash" HEAD 2>/dev/null | grep -vE '^(PLAN\.md|BACKLOG\.md|JOURNAL\.md|JOURNAL-archive\.md)$' | head -n 1)"
          if [ -n "$nonstate" ]; then
            violation="product path $nonstate changed after the Converged hash $conv_hash; certify the current tree before declaring"
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
      if [ -z "$violation" ]; then
        # Verify-command check: the project's own gate must be green at the
        # converged stop. A missing PLAN.md or an absent timeout binary is
        # an infrastructure defect: skip with a stderr note, never trap.
        if [ ! -f "$root/PLAN.md" ]; then
          echo "jeffy stop hook: PLAN.md missing at $root; skipping the verify check." >&2
        elif ! command -v timeout >/dev/null 2>&1; then
          echo "jeffy stop hook: coreutils timeout not found; skipping the verify check." >&2
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
              vt="$(fm verify_timeout_seconds)"
              case "$vt" in '' | *[!0-9]*) vt=240 ;; esac
              ( cd "$root" && timeout "$vt" bash -c "$verify_cmd" ) >/dev/null 2>&1
              vrc=$?
              if [ "$vrc" -eq 124 ]; then
                violation="the Verify command ($verify_cmd) exceeded the ${vt}s timeout; get it green, then re-declare convergence"
              elif [ "$vrc" -ne 0 ]; then
                violation="the Verify command ($verify_cmd) exited $vrc; get it green, then re-declare convergence"
              fi
            fi
          fi
        fi
      fi
      if [ -z "$violation" ]; then
        rm -f "$state"
        exit 0
      fi
      ;;
  esac
fi

# Budget spent: end the run and let the session stop. A convergence claim
# whose checks failed gets a stderr note instead of a silent swallow.
if [ "$iter" -ge "$max" ]; then
  if [ -n "$violation" ]; then
    echo "jeffy stop hook: convergence rejected ($violation) but the budget is spent; ending the run." >&2
  fi
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
# Run identity: the session prefix alone does not name a run. Relaunching
# /jeffy in the same Claude Code session reuses the session id, so several
# runs stamp identical headings and the journal cannot say where one ended -
# observed across six runs and 64 iterations on one project. The started_at
# time from the loop state, which is rewritten at every launch, separates
# them. A state file without it predates this and falls back to the prefix.
runid8="${fm_session:0:8}"
run_tok="$(printf '%s' "$(fm started_at)" | sed -n 's/.*T\([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\).*/\1\2\3/p')"
if [ -n "$run_tok" ]; then
  runid8="$runid8-$run_tok"
fi
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
  dirty="$(git -C "$root" status --porcelain --untracked-files=no 2>/dev/null | head -n 1)"
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

# Stall gate: progress since the previous turn end means HEAD moved or
# BACKLOG.md changed - an audit that files tasks is progress even without a
# commit, and journal-only iterations deliberately count as no progress. The
# first re-feed initializes the baseline and never fires. A flat iteration
# rides a STALL note; the stall flag arms the second-strike stop. With no
# git HEAD and no ledger there is no signal at all: skip with a stderr note.
stall_note=""
new_stall=0
cur_head="none"
if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
  cur_head="$(git -C "$root" rev-parse HEAD 2>/dev/null || echo none)"
fi
cur_backlog="none"
if [ -f "$root/BACKLOG.md" ]; then
  cur_backlog="$(cksum < "$root/BACKLOG.md" | tr ' \t' '--')"
fi
last_head="$(fm last_head)"
last_backlog="$(fm last_backlog)"
stall_flag="$(fm stall)"
if [ "$cur_head" = "none" ] && [ "$cur_backlog" = "none" ]; then
  echo "jeffy stop hook: no git HEAD and no BACKLOG.md; skipping the stall check." >&2
elif [ -n "$last_head" ] || [ -n "$last_backlog" ]; then
  if [ "$cur_head" = "$last_head" ] && [ "$cur_backlog" = "$last_backlog" ]; then
    if [ "$stall_flag" = "1" ]; then
      # Second strike: the prompted hard-blocker close-out did not happen,
      # so the hook ends the stalled run itself, the way budget exhaustion
      # does - state deleted, stop allowed, evidence on stderr.
      echo "jeffy stop hook: two consecutive flat iterations (latest: iteration $iter) with HEAD and BACKLOG.md unchanged; ending the run as stalled." >&2
      rm -f "$state"
      exit 0
    fi
    new_stall=1
    stall_note="iteration $iter made no progress (HEAD and BACKLOG.md unchanged since the previous turn end); a second consecutive flat iteration ends the run"
  fi
fi

tmp="$state.tmp"
# The rewriter owns the keys it names and prints every other line verbatim,
# so the schema is additive: a state file carrying keys this version never
# heard of survives the re-feed untouched. extension_granted and a rewritable
# max_iterations are reserved on that path for the 1.5.0 closing extension.
# archive_migrated rides along with the strict archive baseline it certifies:
# the baseline this rewrite stores is strict, so the naive escape above has
# done its one job and must never be taken again.
if awk -v n="$next" -v lh="$cur_head" -v lb="$cur_backlog" -v sf="$new_stall" -v la="$cur_archive" '
  /^---$/ { fmc++; if (fmc == 2) { if (!slh) print "last_head: " lh; if (!slb) print "last_backlog: " lb; if (!ssf) print "stall: " sf; if (!sla) print "last_archive: " la; if (!sam) print "archive_migrated: 1" } print; next }
  fmc == 1 && /^iteration: / { print "iteration: " n; next }
  fmc == 1 && /^last_head: / { print "last_head: " lh; slh = 1; next }
  fmc == 1 && /^last_backlog: / { print "last_backlog: " lb; slb = 1; next }
  fmc == 1 && /^stall: / { print "stall: " sf; ssf = 1; next }
  fmc == 1 && /^last_archive: / { print "last_archive: " la; sla = 1; next }
  fmc == 1 && /^archive_migrated: / { print "archive_migrated: 1"; sam = 1; next }
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
if [ -n "$violation" ]; then
  reason="$reason CONVERGENCE REJECTED by the stop hook: $violation. Fix this, then re-declare convergence with the promise phrase."
fi
if [ -n "$hygiene" ]; then
  reason="$reason ITERATION HYGIENE: $hygiene."
fi
if [ -n "$stall_note" ]; then
  reason="$reason STALL: $stall_note."
fi
jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
exit 0
